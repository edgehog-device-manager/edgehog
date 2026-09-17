#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Containers.FileBind.Provisioner.Core do
  @moduledoc """
  The module describing the Core functions required by the file bind provisioner.

  Provisioning a file bind means creating the file download request backing
  an uploaded file when the bind has no explicit target, and then sending a
  `CreateFileBindRequest` to the device. Readiness is reported by the device
  through the `AvailableFileBinds` interface, like any other container
  resource.

  For more information, check the `Edgehog.Containers.Provisioner.Core.Behaviour` docs.
  """
  use Edgehog.Containers.Provisioner.Core

  alias Edgehog.Astarte.Device.AvailableFileBinds.FileBindStatus
  alias Edgehog.Containers.FileBind.Storage, as: FileBindStorage
  alias Edgehog.Devices
  alias Edgehog.Files

  require Logger

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def ready?(%{state: state}), do: state in [:available, :unavailable]

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def topic(%{id: id}), do: "ready:file_binds:#{id}"
  def topic(id), do: "ready:file_binds:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def subscribe_topic(%{id: id}), do: "file_binds:#{id}"
  def subscribe_topic(id), do: "file_binds:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def name(%{id: id}),
    do: {:via, Registry, {Edgehog.Containers.FileBind.Provisioner.Registry, id}}

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def temporary_error?(:file_not_uploaded), do: true
  def temporary_error?({:error, :file_not_uploaded}), do: true
  def temporary_error?(error), do: super(error)

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def send_to_device(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, file_bind} <- ensure_file_download_request(resource, tenant),
         {:ok, %{device: device} = file_bind} <-
           Ash.load(file_bind, [:device, :file_mount], tenant: tenant),
         {:ok, device} <-
           Devices.send_create_file_bind_request(device, file_bind, deployment, tenant: tenant) do
      log_provisioning_started(file_bind, device)
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def reconcile(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, resource} <-
           Ash.load(resource, [device: [:available_file_binds]], tenant: tenant),
         {:ok, device} <- Map.fetch(resource, :device),
         {:ok, available_resources} <- Map.fetch(device, :available_file_binds) do
      available_resources
      |> Enum.find(:not_found, &(&1.id == resource.id))
      |> maybe_update(resource, tenant)
    end
  end

  def maybe_update(%FileBindStatus{}, resource, tenant) do
    # NOTE: the device reports file binds as plain properties, without an
    # explicit presence flag. The existence of the bind id in
    # `AvailableFileBinds` means the device has the bind, so we mark it as
    # available. This will trigger a publish on the appropriate topic, which
    # the provisioner will react to.
    resource
    |> Ash.Changeset.for_update(:mark_as_available)
    |> Ash.update(tenant: tenant)
  end

  def maybe_update(other, _resource, _tenant), do: other

  # No explicit target: the file was uploaded through the presigned upload
  # URL. Create a file download request for it and link it to the bind.
  defp ensure_file_download_request(
         %{file_download_request_id: nil, device_file_id: nil} = file_bind,
         tenant
       ) do
    with {:ok, file_bind} <- Ash.load(file_bind, [:container_deployment, :file_download_request_id, :device_file_id], tenant: tenant),
         :needs_target <- check_still_needs_target(file_bind),
         {:ok, file_download_request} <- create_file_download_request(file_bind, tenant) do
      link_file_bind(file_bind, file_download_request, tenant)
    else
      :already_has_target ->
        {:ok, Ash.load!(file_bind, [:file_download_request_id, :device_file_id], tenant: tenant)}

      error ->
        error
    end
  end

  # The bind already has a target, nothing to create.
  defp ensure_file_download_request(file_bind, _tenant), do: {:ok, file_bind}

  defp check_still_needs_target(%{file_download_request_id: nil, device_file_id: nil}), do: :needs_target
  defp check_still_needs_target(_), do: :already_has_target

  defp create_file_download_request(%{uploaded: false}, _tenant) do
    {:error, :file_not_uploaded}
  end

  defp create_file_download_request(file_bind, tenant) do
    %{container_deployment: container_deployment} = file_bind
    tenant_id = tenant_id(tenant)

    file_path = FileBindStorage.file_path(tenant_id, file_bind.id, file_bind.file_name)

    with {:ok, %{get_url: url}} <- FileBindStorage.read_presigned_url(file_path) do
      params = %{
        url: url,
        file_name: file_bind.file_name,
        uncompressed_file_size_bytes: file_bind.uncompressed_file_size_bytes,
        digest: file_bind.digest,
        encoding: file_bind.encoding || "",
        destination_type: :storage,
        device_id: container_deployment.device_id
      }

      case Files.create_file_bind_file_download_request(params, tenant: tenant) do
        {:ok, file_download_request} -> {:ok, file_download_request}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp link_file_bind(file_bind, file_download_request, tenant) do
    with {:ok, fresh} <- Ash.load(file_bind, [:file_download_request_id, :device_file_id], tenant: tenant) do
      case fresh do
        %{file_download_request_id: id} when not is_nil(id) and id != file_download_request.id ->
          # Another provisioner already linked a different request; clean up the new one
          _ = Ash.destroy(file_download_request, tenant: tenant)
          {:ok, fresh}

        %{file_download_request_id: id} when id == file_download_request.id ->
          {:ok, fresh}

        %{device_file_id: id} when not is_nil(id) ->
          _ = Ash.destroy(file_download_request, tenant: tenant)
          {:ok, fresh}

        _ ->
          action_opts = %{file_download_request_id: file_download_request.id}

          case fresh
               |> Ash.Changeset.for_update(:link_file_download_request, action_opts)
               |> Ash.update(tenant: tenant) do
            {:ok, file_bind} -> {:ok, file_bind}
            {:error, reason} -> {:error, reason}
          end
      end
    end
  end

  defp tenant_id(%{tenant_id: tenant_id}), do: tenant_id
  defp tenant_id(tenant_id), do: tenant_id

  # Logging functions

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_started(resource, device) do
    Logger.info("""
    FileBind #{resource.id} provisioned on device #{device.device_id}. Waiting events
    """)
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_api_error(resource, error) do
    if temporary_error?(error) do
      Logger.warning(
        "Error while sending the file bind #{resource.id}: #{inspect(error)}. The operation will be retried shortly."
      )
    else
      Logger.error(
        "Unrecoverable error while sending the file bind #{resource.id}: #{inspect(error)}. Terminating."
      )
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_failed(resource, reason) do
    Logger.info(
      "Provisioner for file bind #{resource.id} gave up with reason #{inspect(reason)}."
    )
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_completed(resource, retries) do
    Logger.info("FileBind #{resource.id} successfully provisioned after #{retries} retries.")
  end
end
