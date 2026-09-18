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

defmodule Edgehog.Containers.EnvFile.Provisioner.Core do
  @moduledoc """
  The module describing the Core functions required by the env file provisioner.

  Provisioning an env file means creating the file download request backing
  an uploaded file when the env file has no explicit target, and then sending a
  `CreateEnvFileRequest` to the device. Readiness is reported by the device
  through the `AvailableEnvFiles` interface, like any other container
  resource.

  For more information, check the `Edgehog.Containers.Provisioner.Core.Behaviour` docs.
  """
  use Edgehog.Containers.Provisioner.Core

  alias Edgehog.Astarte.Device.AvailableEnvFiles.EnvFileStatus
  alias Edgehog.Containers.EnvFile.Storage, as: EnvFileStorage
  alias Edgehog.Devices
  alias Edgehog.Files

  require Logger

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def ready?(%{state: state}), do: state in [:available, :unavailable]

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def topic(%{id: id}), do: "ready:env_files:#{id}"
  def topic(id), do: "ready:env_files:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def subscribe_topic(%{id: id}), do: "env_files:#{id}"
  def subscribe_topic(id), do: "env_files:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def name(%{id: id}),
    do: {:via, Registry, {Edgehog.Containers.EnvFile.Provisioner.Registry, id}}

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def temporary_error?(:file_not_uploaded), do: true
  def temporary_error?({:error, :file_not_uploaded}), do: true
  def temporary_error?(error), do: super(error)

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def send_to_device(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, env_file} <- ensure_file_download_request(resource, tenant),
         {:ok, %{device: device} = env_file} <-
           Ash.load(env_file, [:device], tenant: tenant),
         {:ok, device} <-
           Devices.send_create_env_file_request(device, env_file, deployment, tenant: tenant) do
      log_provisioning_started(env_file, device)
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def reconcile(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, resource} <-
           Ash.load(resource, [device: [:available_env_files]], tenant: tenant),
         {:ok, device} <- Map.fetch(resource, :device),
         {:ok, available_resources} <- Map.fetch(device, :available_env_files) do
      available_resources
      |> Enum.find(:not_found, &(&1.id == resource.id))
      |> maybe_update(resource, tenant)
    end
  end

  def maybe_update(%EnvFileStatus{}, resource, tenant) do
    resource
    |> Ash.Changeset.for_update(:mark_as_available)
    |> Ash.update(tenant: tenant)
  end

  def maybe_update(other, _resource, _tenant), do: other

  # No explicit target: the file was uploaded through the presigned upload
  # URL. Create a file download request for it and link it to the env file.
  defp ensure_file_download_request(
         %{file_download_request_id: nil, device_file_id: nil} = env_file,
         tenant
       ) do
    with {:ok, env_file} <-
           Ash.load(
             env_file,
             [:container_deployment, :file_download_request_id, :device_file_id],
             tenant: tenant
           ),
         :needs_target <- check_still_needs_target(env_file),
         {:ok, file_download_request} <- create_file_download_request(env_file, tenant) do
      link_env_file(env_file, file_download_request, tenant)
    else
      :already_has_target ->
        {:ok, Ash.load!(env_file, [:file_download_request_id, :device_file_id], tenant: tenant)}

      error ->
        error
    end
  end

  # The env file already has a target, nothing to create.
  defp ensure_file_download_request(env_file, _tenant), do: {:ok, env_file}

  defp check_still_needs_target(%{file_download_request_id: nil, device_file_id: nil}),
    do: :needs_target

  defp check_still_needs_target(_), do: :already_has_target

  defp create_file_download_request(%{uploaded: false}, _tenant) do
    {:error, :file_not_uploaded}
  end

  defp create_file_download_request(env_file, tenant) do
    env_file =
      case Map.get(env_file, :container_deployment) do
        nil ->
          {:ok, loaded} = Ash.load(env_file, [:container_deployment], tenant: tenant)
          loaded

        _ ->
          env_file
      end

    %{container_deployment: container_deployment} = env_file
    tenant_id = tenant_id(tenant)

    file_path = EnvFileStorage.file_path(tenant_id, env_file.id, env_file.file_name)

    with {:ok, %{get_url: url}} <- EnvFileStorage.read_presigned_url(file_path) do
      params = %{
        url: url,
        file_name: env_file.file_name,
        uncompressed_file_size_bytes: env_file.uncompressed_file_size_bytes,
        digest: env_file.digest,
        encoding: env_file.encoding || "",
        destination_type: :storage,
        device_id: container_deployment.device_id
      }

      Files.create_env_file_file_download_request(params, tenant: tenant)
    end
  end

  defp link_env_file(env_file, file_download_request, tenant) do
    with {:ok, fresh} <-
           Ash.load(env_file, [:file_download_request_id, :device_file_id], tenant: tenant) do
      case fresh do
        %{file_download_request_id: id} when id == file_download_request.id ->
          {:ok, fresh}

        %{file_download_request_id: file_id} when is_binary(file_id) ->
          # Another provisioner already linked a different request; clean up the new one
          _ = Ash.destroy(file_download_request, tenant: tenant)
          {:ok, fresh}

        %{device_file_id: device_file_id} when is_binary(device_file_id) ->
          _ = Ash.destroy(file_download_request, tenant: tenant)
          {:ok, fresh}

        _ ->
          action_opts = %{file_download_request_id: file_download_request.id}

          fresh
          |> Ash.Changeset.for_update(:link_file_download_request, action_opts)
          |> Ash.update(tenant: tenant)
      end
    end
  end

  defp tenant_id(%{tenant_id: tenant_id}), do: tenant_id
  defp tenant_id(tenant_id), do: tenant_id

  # Logging functions

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_started(resource, device) do
    Logger.info("""
    EnvFile #{resource.id} provisioned on device #{device.device_id}. Waiting events
    """)
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_api_error(resource, error) do
    if temporary_error?(error) do
      Logger.warning(
        "Error while sending the env file #{resource.id}: #{inspect(error)}. The operation will be retried shortly."
      )
    else
      Logger.error(
        "Unrecoverable error while sending the env file #{resource.id}: #{inspect(error)}. Terminating."
      )
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_failed(resource, reason) do
    Logger.info("Provisioner for env file #{resource.id} gave up with reason #{inspect(reason)}.")
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_completed(resource, retries) do
    Logger.info("EnvFile #{resource.id} successfully provisioned after #{retries} retries.")
  end
end
