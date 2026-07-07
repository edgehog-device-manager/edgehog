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

defmodule Edgehog.Containers.Container.Deployment.Supervisor.Core do
  @moduledoc """
  Container Supervisor core functions.
  """

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.DeviceMapping
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Volume

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
      :device_mapping_deployments
    ]

    # Bang: if the database connection is not working it does not make sense to
    # do all of this

    container_deployment = Ash.load!(container_deployment, to_load, tenant: tenant)

    # Bang: if there is no image deployment it's a massive error, we should
    # crash
    image_deployment = Map.fetch!(container_deployment, :image_deployment)

    network_deployments = Map.get(container_deployment, :network_deployments, [])
    volume_deployments = Map.get(container_deployment, :volume_deployments, [])
    device_mapping_deployments = Map.get(container_deployment, :device_mapping_deployments, [])

    state
    |> Map.put(:image_deployment, image_deployment)
    |> Map.put(:network_deployments, network_deployments)
    |> Map.put(:volume_deployments, volume_deployments)
    |> Map.put(:device_mapping_deployments, device_mapping_deployments)
  end

  @doc """
  Starts the provisioner for each underlying deployment. Subscribing the caller to relevant changes.

  Returns the state updated with 
  """
  def provision(state) do
    state
    |> provision_image()
    |> provision_volumes()
    |> provision_networks()
    |> provision_device_mappings()
    |> provision_container()
  end

  def provision_image(state) do
    %{
      image_deployment: image_deployment,
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = image_deployment

    # Subscribe to the image_deployment readiness
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "ready:image_deployment:#{id}")

    # Start the provisioner
    Image.Deployment.Provisioner.provision(image_deployment, deployment, tenant)

    Map.put(state, :image_provisioning, :started)
  end

  def provision_volumes(state) do
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
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "ready:volume_deployment:#{id}")

    # Start the provisioner
    Volume.Deployment.Provisioner.provision(volume_deployment, deployment, tenant)

    # Append to the queue of volumes to wait for readiness
    Map.update(state, :volumes_to_provision, [], &[volume_deployment | &1])
  end

  def provision_networks(state) do
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
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "ready:network_deployment:#{id}")

    # Start the provisioner
    Network.Deployment.Provisioner.provision(network_deployment, deployment, tenant)

    # Append to the queue of networks to wait for readiness
    Map.update(state, :networks_to_provision, [], &[network_deployment | &1])
  end

  def provision_device_mappings(state) do
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
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "ready:device_mapping_deployment:#{id}")

    # Start the provisioner
    DeviceMapping.Deployment.Provisioner.provision(device_mapping_deployment, deployment, tenant)

    # Append to the queue of device mappings to wait for readiness
    Map.update(state, :device_mappings_to_provision, [], &[device_mapping_deployment | &1])
  end

  def provision_container(state) do
    %{
      container_deployment: container_deployment,
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = container_deployment

    # Subscribe to the container_deployment readiness
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "ready:container_deployment:#{id}")

    # Start the provisioner
    Container.Deployment.Provisioner.provision(container_deployment, deployment, tenant)

    Map.put(state, :container_provisioning, :started)
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

    image_ready and
      container_ready and
      volumes_ready and
      networks_ready and
      device_mappings_ready
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
end
