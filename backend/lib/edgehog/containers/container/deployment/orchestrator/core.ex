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

defmodule Edgehog.Containers.Container.Deployment.Orchestrator.Core do
  @moduledoc """
  Container orchestrator pure functions.
  """

  alias Edgehog.Containers.Container.Deployment.Provisioner, as: ContainerProvisioner
  alias Edgehog.Containers.DeviceMapping
  alias Edgehog.Containers.DeviceRequest
  alias Edgehog.Containers.FileBind.Storage, as: FileBindStorage
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Volume
  alias Edgehog.Files
  alias Edgehog.Files.FileDownloadRequest.Provisioner, as: FileProvisioner

  require Logger

  @doc """
  Loads the necessary resources and puts them in the state.

  Returns the state with all the resources loaded in their respective keys.
  """
  def load_resources(state) do
    %{
      container_deployment: container_deployment,
      tenant: tenant
    } = state

    to_load = [
      :image_deployment,
      :network_deployments,
      :volume_deployments,
      :device_mapping_deployments,
      :device_request_deployments,
      :file_binds
    ]

    with {:ok, container_deployment} <- Ash.load(container_deployment, to_load, tenant: tenant) do
      # Bang: if there is no image deployment it's a massive error, we should
      # crash
      image_deployment = Map.fetch!(container_deployment, :image_deployment)

      network_deployments = Map.get(container_deployment, :network_deployments, [])
      volume_deployments = Map.get(container_deployment, :volume_deployments, [])
      device_mapping_deployments = Map.get(container_deployment, :device_mapping_deployments, [])
      device_request_deployments = Map.get(container_deployment, :device_request_deployments, [])
      file_binds = Map.get(container_deployment, :file_binds, [])

      {:ok,
       state
       |> Map.put(:container_deployment, container_deployment)
       |> Map.put(:image_deployment, image_deployment)
       |> Map.put(:network_deployments, network_deployments)
       |> Map.put(:volume_deployments, volume_deployments)
       |> Map.put(:device_mapping_deployments, device_mapping_deployments)
       |> Map.put(:device_request_deployments, device_request_deployments)
       |> Map.put(:file_binds, file_binds)}
    end
  end

  def ready?(state) do
    image_ready = Map.fetch!(state, :image_provisioning) == :completed
    container_ready = Map.fetch!(state, :container_provisioning) == :completed

    volumes_ready =
      state
      |> Map.fetch!(:volumes_to_provision)
      |> Enum.empty?()

    networks_ready =
      state
      |> Map.fetch!(:networks_to_provision)
      |> Enum.empty?()

    device_mappings_ready =
      state
      |> Map.fetch!(:device_mappings_to_provision)
      |> Enum.empty?()

    device_requests_ready =
      state
      |> Map.fetch!(:device_requests_to_provision)
      |> Enum.empty?()

    files_ready =
      state
      |> Map.fetch!(:files_to_provision)
      |> Enum.empty?()

    image_ready and
      container_ready and
      volumes_ready and
      networks_ready and
      device_mappings_ready and
      device_requests_ready and
      files_ready
  end

  @doc """
  Sets image provisioning to :completed

  Example:
  (%{image_provisioning: :started}) -> %{image_provisioning: :completed}
  """
  def image_ready(state) do
    %{
      state
      | image_provisioning: :completed
    }
  end

  @doc """
  Sets container provisioning to :completed

  Example:
  (%{container_provisioning: :started}) -> %{container_provisioning: :completed}
  """
  def container_ready(state) do
    %{
      state
      | container_provisioning: :completed
    }
  end

  @doc """
  Removes a volume from the list of volumes that need to be provisioned.

  The list of volumes to be provisioned is expected to be a list of volume
  deployments in the key `:volumes_to_provision` into the state.

  Example:
  if id matches depl2

  (id, %{volumes_to_provision: [depl1, depl2, depl3, ...]}) -> %{volumes_to_provision: [depl1, depl3, ...]}
  """
  def volume_ready(id, state) do
    id_matches = &(&1.id == id)

    remove_matching_volume = &Enum.reject(&1, id_matches)

    Map.update!(state, :volumes_to_provision, remove_matching_volume)
  end

  @doc """
  Removes a network from the list of networks that need to be provisioned.

  The list of networks to be provisioned is expected to be a list of network
  deployments in the key `:networks_to_provision` into the state.

  Example:
  if id matches depl2

  (id, %{networks_to_provision: [depl1, depl2, depl3, ...]}) -> %{networks_to_provision: [depl1, depl3, ...]}
  """
  def network_ready(id, state) do
    id_matches = &(&1.id == id)

    remove_matching_network = &Enum.reject(&1, id_matches)

    Map.update!(state, :networks_to_provision, remove_matching_network)
  end

  @doc """
  Removes a device mapping from the list of device mappings that need to be provisioned.

  The list of device mappings to be provisioned is expected to be a list of device mapping
  deployments in the key `:device_mappings_to_provision` into the state.

  Example:
  if id matches depl2

  (id, %{device_mappings_to_provision: [depl1, depl2, depl3, ...]}) -> %{device_mappings_to_provision: [depl1, depl3, ...]}
  """
  def device_mapping_ready(id, state) do
    id_matches = &(&1.id == id)

    remove_matching_device_mapping = &Enum.reject(&1, id_matches)

    Map.update!(state, :device_mappings_to_provision, remove_matching_device_mapping)
  end

  @doc """
  Removes a device request from the list of device requests that need to be provisioned.

  The list of device requests to be provisioned is expected to be a list of device request
  deployments in the key `:device_requests_to_provision` into the state.

  Example:
  if id matches depl2

  (id, %{device_requests_to_provision: [depl1, depl2, depl3, ...]}) -> %{device_requests_to_provision: [depl1, depl3, ...]}
  """
  def device_request_ready(id, state) do
    id_matches = &(&1.id == id)

    remove_matching_device_request = &Enum.reject(&1, id_matches)

    Map.update!(state, :device_requests_to_provision, remove_matching_device_request)
  end

  @doc """
  Removes a file download request from the list of files that need to be provisioned.

  The list of files to be provisioned is expected to be a list of file
  download requests in the key `:files_to_provision` into the state.
  """
  def file_ready(id, state) do
    id_matches = &(&1.id == id)

    remove_matching_file = &Enum.reject(&1, id_matches)

    Map.update!(state, :files_to_provision, remove_matching_file)
  end

  def provision(state) do
    state
    |> provision_image()
    |> provision_volumes()
    |> provision_networks()
    |> provision_device_mappings()
    |> provision_device_requests()
    |> provision_files()
    |> provision_container()
  end

  defp provision_image(state) do
    %{
      image_deployment: image_deployment,
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = image_deployment

    # Subscribe to the image_deployment readiness
    Phoenix.PubSub.subscribe(
      Edgehog.PubSub,
      Image.Deployment.Provisioner.Core.topic(image_deployment)
    )

    case Image.Deployment.Provisioner.provision(
           image_deployment,
           tenant,
           deployment: deployment,
           mode: state.mode
         ) do
      {:ok, _pid} ->
        Map.put(state, :image_provisioning, :started)

      {:error, reason} ->
        log_provisioner_start_failed("image", id, reason)

        state
        |> Map.put(:image_provisioning, :failed)
        |> Map.put(:provisioning_failed, true)
    end
  end

  defp provision_volumes(state) do
    new_state = Map.put(state, :volumes_to_provision, [])

    new_state
    |> Map.get(:volume_deployments, [])
    |> Enum.reduce(new_state, &provision_volume/2)
  end

  defp provision_volume(volume_deployment, state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = volume_deployment

    # Subscribe to the volume_deployment readiness
    Phoenix.PubSub.subscribe(
      Edgehog.PubSub,
      Volume.Deployment.Provisioner.Core.topic(volume_deployment)
    )

    # Start the provisioner
    case Volume.Deployment.Provisioner.provision(volume_deployment, tenant,
           deployment: deployment,
           mode: state.mode
         ) do
      {:ok, _pid} ->
        Map.update(state, :volumes_to_provision, [], &[volume_deployment | &1])

      {:error, reason} ->
        log_provisioner_start_failed("volume", id, reason)

        state
        |> Map.put(:volume_provisioning, :failed)
        |> Map.put(:provisioning_failed, true)
    end
  end

  defp provision_networks(state) do
    new_state = Map.put(state, :networks_to_provision, [])

    new_state
    |> Map.get(:network_deployments, [])
    |> Enum.reduce(new_state, &provision_network/2)
  end

  defp provision_network(network_deployment, state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = network_deployment

    # Subscribe to the network_deployment readiness
    Phoenix.PubSub.subscribe(
      Edgehog.PubSub,
      Network.Deployment.Provisioner.Core.topic(network_deployment)
    )

    # Start the provisioner
    case Network.Deployment.Provisioner.provision(network_deployment, tenant,
           deployment: deployment,
           mode: state.mode
         ) do
      {:ok, _pid} ->
        Map.update(state, :networks_to_provision, [], &[network_deployment | &1])

      {:error, reason} ->
        log_provisioner_start_failed("network", id, reason)

        state
        |> Map.put(:network_provisioning, :failed)
        |> Map.put(:provisioning_failed, true)
    end
  end

  defp provision_device_mappings(state) do
    new_state = Map.put(state, :device_mappings_to_provision, [])

    new_state
    |> Map.get(:device_mapping_deployments, [])
    |> Enum.reduce(new_state, &provision_device_mapping/2)
  end

  defp provision_device_mapping(device_mapping_deployment, state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = device_mapping_deployment

    # Subscribe to the device_mapping_deployment readiness
    Phoenix.PubSub.subscribe(
      Edgehog.PubSub,
      DeviceMapping.Deployment.Provisioner.Core.topic(device_mapping_deployment)
    )

    # Start the provisioner
    provisioner =
      DeviceMapping.Deployment.Provisioner.provision(
        device_mapping_deployment,
        tenant,
        deployment: deployment,
        mode: state.mode
      )

    case provisioner do
      {:ok, _pid} ->
        Map.update(state, :device_mappings_to_provision, [], &[device_mapping_deployment | &1])

      {:error, reason} ->
        log_provisioner_start_failed("device_mapping", id, reason)

        state
        |> Map.put(:device_mapping_provisioning, :failed)
        |> Map.put(:provisioning_failed, true)
    end
  end

  defp provision_device_requests(state) do
    new_state = Map.put(state, :device_requests_to_provision, [])

    new_state
    |> Map.get(:device_request_deployments, [])
    |> Enum.reduce(new_state, &provision_device_request/2)
  end

  defp provision_device_request(device_request_deployment, state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = device_request_deployment

    # Subscribe to the device_request_deployment readiness
    Phoenix.PubSub.subscribe(
      Edgehog.PubSub,
      DeviceRequest.Deployment.Provisioner.Core.topic(device_request_deployment)
    )

    # Start the provisioner
    provisioner =
      DeviceRequest.Deployment.Provisioner.provision(
        device_request_deployment,
        tenant,
        deployment: deployment,
        mode: state.mode
      )

    case provisioner do
      {:ok, _pid} ->
        Map.update(state, :device_requests_to_provision, [], &[device_request_deployment | &1])

      {:error, reason} ->
        log_provisioner_start_failed("device_request", id, reason)

        state
        |> Map.put(:device_request_provisioning, :failed)
        |> Map.put(:provisioning_failed, true)
    end
  end

  defp provision_files(state) do
    new_state = Map.put(state, :files_to_provision, [])

    new_state
    |> Map.get(:file_binds, [])
    |> Enum.reduce(new_state, &provision_file/2)
  end

  # No explicit target: the file was uploaded through the presigned upload
  # URL. Create a file download request for it, link it to the bind and
  # track it like any other provisioned resource.
  defp provision_file(%{file_download_request_id: nil, file_device_id: nil} = file_bind, state) do
    %{tenant: tenant, deployment: deployment} = state

    with {:ok, file_download_request} <- create_file_download_request(file_bind, state),
         {:ok, _file_bind} <- link_file_bind(file_bind, file_download_request, tenant) do
      track_file(file_download_request, state, deployment, tenant)
    else
      {:error, reason} ->
        log_provisioner_start_failed("file", file_bind.id, reason)

        state
        |> Map.put(:file_provisioning, :failed)
        |> Map.put(:provisioning_failed, true)
    end
  end

  # The file is already on the device, nothing to provision.
  defp provision_file(
         %{device_file_id: _device_file_id, file_download_request_id: nil} = _file_bind,
         state
       ) do
    state
  end

  # The bind already references a file download request: track it like any
  # other provisioned resource.
  defp provision_file(
         %{file_download_request_id: request_id, file_device_id: nil} = _file_bind,
         state
       ) do
    %{tenant: tenant, deployment: deployment} = state

    case Files.fetch_file_download_request(request_id, tenant: tenant) do
      {:ok, file_download_request} ->
        track_file(file_download_request, state, deployment, tenant)

      {:error, reason} ->
        log_provisioner_start_failed("file", request_id, reason)

        state
        |> Map.put(:file_provisioning, :failed)
        |> Map.put(:provisioning_failed, true)
    end
  end

  defp create_file_download_request(%{uploaded: false} = _file_bind, _state) do
    {:error, :file_not_uploaded}
  end

  defp create_file_download_request(file_bind, state) do
    %{container_deployment: container_deployment, tenant: tenant} = state
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
    case file_bind
         |> Ash.Changeset.for_update(:link_file_download_request, %{
           file_download_request_id: file_download_request.id
         })
         |> Ash.update(tenant: tenant) do
      {:ok, file_bind} -> {:ok, file_bind}
      {:error, reason} -> {:error, reason}
    end
  end

  defp track_file(file_download_request, state, deployment, tenant) do
    %{id: id} = file_download_request

    # Subscribe to the file download request readiness
    Phoenix.PubSub.subscribe(
      Edgehog.PubSub,
      FileProvisioner.Core.topic(file_download_request)
    )

    # Start the provisioner
    case FileProvisioner.provision(file_download_request, tenant,
           deployment: deployment,
           mode: state.mode
         ) do
      {:ok, _pid} ->
        Map.update(state, :files_to_provision, [], &[file_download_request | &1])

      {:error, reason} ->
        log_provisioner_start_failed("file", id, reason)

        state
        |> Map.put(:file_provisioning, :failed)
        |> Map.put(:provisioning_failed, true)
    end
  end

  defp tenant_id(%{tenant_id: tenant_id}), do: tenant_id
  defp tenant_id(tenant_id), do: tenant_id

  defp provision_container(state) do
    %{
      container_deployment: container_deployment,
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = container_deployment

    topic = ContainerProvisioner.Core.topic(container_deployment)

    # Subscribe to the container_deployment readiness
    Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

    # Start the provisioner
    case ContainerProvisioner.provision(container_deployment, tenant,
           deployment: deployment,
           mode: state.mode
         ) do
      {:ok, _pid} ->
        state
        |> Map.update(:containers_to_provision, [], &[container_deployment | &1])
        |> Map.put(:container_provisioning, :started)

      {:error, reason} ->
        log_provisioner_start_failed("container", id, reason)

        state
        |> Map.put(:container_provisioning, :failed)
        |> Map.put(:provisioning_failed, true)
    end
  end

  # Logging functions

  def log_resources_loading(container_deployment_id) do
    Logger.debug("Loading resources for container deployment #{container_deployment_id}")
  end

  def log_load_resources_failed(container_deployment_id, reason) do
    Logger.error("""
    Error while loading the resources for container deployment #{container_deployment_id}: #{inspect(reason)}.

    The container deployment will be marked as failed.
    """)
  end

  def log_provisioner_failed(container_deployment_id) do
    Logger.warning(
      "A provisioner for container deployment #{container_deployment_id} gave up. Failing the container deployment."
    )
  end

  def log_provisioning_failed(container_deployment_id) do
    Logger.warning("Container deployment #{container_deployment_id} provisioning failed.")
  end

  def log_provisioner_start_failed(resource_type, resource_id, reason) do
    Logger.warning(
      "Error while starting #{resource_type} #{resource_id} provisioner: #{inspect(reason)}"
    )
  end
end
