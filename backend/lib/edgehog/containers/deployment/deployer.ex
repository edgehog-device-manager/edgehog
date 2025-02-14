#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Deployer do
  @moduledoc """
  Deployer state machine.
  This module once started is responsible for interacting with the device sending
  all the necessary data to deploy a release on a device.
  """
  use GenStateMachine, restart: :transient, callback_mode: [:handle_event_function, :state_enter]

  alias __MODULE__, as: Data
  alias Edgehog.Containers
  alias Edgehog.Devices
  alias Edgehog.PubSub

  require Logger

  # All elements in the struct are either IDs or lists of IDs, so that the state
  # is more lightweight and the correct informations are retrived from the
  # database when needed.
  defstruct [
    :images,
    :networks,
    :volumes,
    :containers,
    :deployment_id,
    :device_id,
    :tenant_id,
    :resources_to_check
  ]

  # Public API
  def start_link(opts) do
    name = opts[:args] || __MODULE__

    GenStateMachine.start_link(__MODULE__, opts, name: name)
  end

  # Callbacks

  @impl GenStateMachine
  def init(opts) do
    tenant = Keyword.fetch!(opts, :tenant_id)
    deployment = Keyword.fetch!(opts, :deployment_id)

    data = %Data{
      tenant_id: tenant,
      deployment_id: deployment,
      resources_to_check: []
    }

    if opts[:wait_for_start_execution] do
      # Use this to manually start the executor in tests
      {:ok, :wait_for_start_execution, data}
    else
      {:ok, :initialization, data, internal_event(:init_data)}
    end
  end

  # State: :wait_for_start_execution

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :wait_for_start_execution, _data) do
    :keep_state_and_data
  end

  def handle_event(:info, :start_execution, :wait_for_start_execution, data) do
    {:next_state, :initialization, data, internal_event(:init_data)}
  end

  # State: :initialization

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :initialization, data) do
    %Data{deployment_id: deployment_id} = data

    Logger.info("Deployment #{deployment_id}: entering the :initialization state")

    :keep_state_and_data
  end

  def handle_event(:internal, :init_data, :initialization, data) do
    %Data{
      deployment_id: deployment_id,
      tenant_id: tenant_id
    } = data

    deployment =
      Containers.fetch_deployment!(deployment_id,
        tenant: tenant_id,
        load: [release: [containers: [:image, :networks, :volumes]], device: []]
      )

    containers = deployment.release.containers

    images =
      containers
      |> Enum.map(& &1.image_id)
      |> Enum.uniq()

    networks =
      containers
      |> Enum.flat_map(& &1.networks)
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    volumes =
      containers
      |> Enum.flat_map(& &1.volumes)
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    containers = Enum.map(containers, & &1.id)

    new_data = %Data{
      images: images,
      networks: networks,
      volumes: volumes,
      containers: containers,
      device_id: deployment.device.id,
      deployment_id: deployment_id,
      tenant_id: tenant_id
    }

    {:next_state, :deploy_images, new_data, internal_event(:deploy_next_image)}
  end

  # State: :deploy_images

  def handle_event(:enter, _old_state, :deploy_images, data) do
    Logger.info("Deployment #{data.deployment_id}: entering :deploy_images state")

    :keep_state_and_data
  end

  # Fetch the next image, updating the remaining images list, if all images have
  # been deployed, (hence removed from the list), deploy networks.
  def handle_event(:internal, :deploy_next_image, :deploy_images, data) do
    %Data{images: images} = data

    case images do
      [] ->
        {:next_state, :deploy_networks, data, internal_event(:deploy_next_network)}

      [image | rest] ->
        new_data = Map.put(data, :images, rest)
        {:keep_state, new_data, internal_event({:deploy_image, image})}
    end
  end

  def handle_event(:internal, {:deploy_image, image_id}, :deploy_images, data) do
    %Data{device_id: device_id, tenant_id: tenant, resources_to_check: res_list} = data
    PubSub.subscribe_to_events_for(image_id: image_id, device_id: device_id, tenant: tenant)

    with {:ok, image} <- Containers.fetch_image(image_id, tenant: tenant),
         {:ok, device} <- Devices.fetch_device(device_id, tenant: tenant),
         {:ok, _image_deployment} <- Containers.deploy_image(image, device, tenant: tenant) do
      new_resources = [image_id | res_list]
      new_data = Map.put(data, :resources_to_check, new_resources)

      {:keep_state, new_data, internal_event(:deploy_next_image)}
    else
      error -> terminate_on_error(error, data)
    end
  end

  # State: :deploy_networks

  def handle_event(:enter, _old_state, :deploy_networks, data) do
    Logger.info("Deployment #{data.deployment_id}: entering :deploy_network state")

    :keep_state_and_data
  end

  # Fetch the next network, updating the remaining networks list, if all networks have
  # been deployed, (hence removed from the list), deploy volumes.
  def handle_event(:internal, :deploy_next_network, :deploy_networks, data) do
    %Data{networks: networks} = data

    case networks do
      [] ->
        {:next_state, :deploy_volumes, data, internal_event(:deploy_next_volume)}

      [network | rest] ->
        new_data = Map.put(data, :networks, rest)
        {:keep_state, new_data, internal_event({:deploy_network, network})}
    end
  end

  def handle_event(:internal, {:deploy_network, network_id}, :deploy_networks, data) do
    %Data{device_id: device_id, tenant_id: tenant, resources_to_check: res_list} = data
    PubSub.subscribe_to_events_for(network_id: network_id, device_id: device_id, tenant: tenant)

    with {:ok, network} <- Containers.fetch_network(network_id, tenant: tenant),
         {:ok, device} <- Devices.fetch_device(device_id, tenant: tenant),
         {:ok, _network_deployment} <- Containers.deploy_network(network, device, tenant: tenant) do
      new_resources = [network_id | res_list]
      new_data = Map.put(data, :resources_to_check, new_resources)

      {:keep_state, new_data, internal_event(:deploy_next_network)}
    else
      error -> terminate_on_error(error, data)
    end
  end

  # State: :deploy_volumes

  def handle_event(:enter, _old_state, :deploy_volumes, data) do
    Logger.info("Deployment #{data.deployment_id}: entering :deploy_volumes state")

    :keep_state_and_data
  end

  # Fetch the next volume, updating the remaining volumes list, if all volumes have
  # been deployed, (hence removed from the list), deploy containers.
  def handle_event(:internal, :deploy_next_volume, :deploy_volumes, data) do
    %Data{volumes: volumes} = data

    case volumes do
      [] ->
        {:next_state, :deploy_containers, data, internal_event(:deploy_next_container)}

      [volume | rest] ->
        new_data = Map.put(data, :volumes, rest)
        {:keep_state, new_data, internal_event({:deploy_volume, volume})}
    end
  end

  def handle_event(:internal, {:deploy_volume, volume_id}, :deploy_volumes, data) do
    %Data{device_id: device_id, tenant_id: tenant, resources_to_check: res_list} = data
    PubSub.subscribe_to_events_for(volume_id: volume_id, device_id: device_id, tenant: tenant)

    with {:ok, volume} <- Containers.fetch_volume(volume_id, tenant: tenant),
         {:ok, device} <- Devices.fetch_device(device_id, tenant: tenant),
         {:ok, _volume_deployment} <- Containers.deploy_volume(volume, device, tenant: tenant) do
      new_resources = [volume_id | res_list]
      new_data = Map.put(data, :resources_to_check, new_resources)

      {:keep_state, new_data, internal_event(:deploy_next_volume)}
    else
      error -> terminate_on_error(error, data)
    end
  end

  # State: :deploy_containers

  def handle_event(:enter, _old_state, :deploy_containers, data) do
    Logger.info("Deployment #{data.deployment_id}: entering :deploy_volumes state")

    :keep_state_and_data
  end

  # Fetch the next container, updating the remaining containers list, if all containers have
  # been deployed, (hence removed from the list), deploy the release.
  def handle_event(:internal, :deploy_next_container, :deploy_containers, data) do
    %Data{containers: containers} = data

    case containers do
      [] ->
        {:next_state, :send_deployment, data, internal_event(:deploy_release)}

      [container | rest] ->
        new_data = Map.put(data, :containers, rest)
        {:keep_state, new_data, internal_event({:deploy_container, container})}
    end
  end

  def handle_event(:internal, {:deploy_container, container_id}, :deploy_containers, data) do
    %Data{device_id: device_id, tenant_id: tenant, resources_to_check: res_list} = data

    PubSub.subscribe_to_events_for(
      container_id: container_id,
      device_id: device_id,
      tenant: tenant
    )

    with {:ok, container} <- Containers.fetch_container(container_id, tenant: tenant),
         {:ok, device} <- Devices.fetch_device(device_id, tenant: tenant),
         {:ok, _container_deployment} <-
           Containers.deploy_container(container, device, tenant: tenant) do
      new_resources = [container_id | res_list]
      new_data = Map.put(data, :resources_to_check, new_resources)

      {:keep_state, new_data, internal_event(:deploy_next_container)}
    else
      error -> terminate_on_error(error, data)
    end
  end

  # State: :deploy_release

  def handle_event(:enter, _old_state, :send_deployment, data) do
    Logger.info("Deployment #{data.deployment_id}: entering :send_deployment state")

    :keep_state_and_data
  end

  def handle_event(:internal, :deploy_release, :send_deployment, data) do
    %Data{
      deployment_id: deployment_id,
      tenant_id: tenant,
      resources_to_check: res_list
    } = data

    PubSub.subscribe_to_events_for(
      deployment_id: deployment_id,
      tenant: tenant
    )

    with {:ok, deployment} <-
           Containers.fetch_deployment(deployment_id, tenant: tenant, load: :device),
         {:ok, _device} <-
           Devices.send_create_deployment_request(deployment.device, deployment, tenant: tenant) do
      new_resources = [deployment_id | res_list]
      new_data = Map.put(data, :resources_to_check, new_resources)

      {:next_state, :check_resources, new_data}
    else
      error -> terminate_on_error(error, data)
    end
  end

  # State: :check_resources

  def handle_event(:enter, _old_state, :check_resources, data) do
    %Data{deployment_id: deployment_id} = data

    Logger.info("Entering state :check_resources for deployment of release #{deployment_id}",
      tag: "deployment_check_resources"
    )

    :keep_state_and_data
  end

  def handle_event(:info, {event, resource_id}, :check_resources, data) do
    %Data{resources_to_check: resources_ids, deployment_id: deployment_id} = data

    Logger.debug(
      "Got event #{inspect(event)} for resource #{resource_id} in deployment #{deployment_id}",
      tag: "deployment_event_#{inspect(event)}"
    )

    new_resources_list = List.delete(resources_ids, resource_id)
    new_data = Map.put(data, :resources_to_check, new_resources_list)

    if new_resources_list == [],
      do: {:next_state, :run_ready_actions, new_data},
      else: {:keep_state, new_data}
  end

  def handle_event(:info, :available_deployment, :check_resources, data) do
    %Data{resources_to_check: resources_ids, deployment_id: deployment_id} = data

    new_resources_list = List.delete(resources_ids, deployment_id)
    new_data = Map.put(data, :resources_to_check, new_resources_list)

    if new_resources_list == [],
      do: {:next_state, :run_ready_actions, new_data},
      else: {:keep_state, new_data}
  end

  # State: :run_ready_actions ## terminal

  def handle_event(:enter, _old_state, :run_ready_actions, data) do
    %Data{deployment_id: deployment_id, tenant_id: tenant} = data

    Logger.info(
      "Entering state :run_ready_actions for deployment #{deployment_id}: terminal state",
      tag: "deployment_run_ready_actions"
    )

    # Terminal state, Run the ready actions for the deployment and then terminate the process normally
    case Containers.fetch_deployment(deployment_id, tenant: tenant) do
      {:ok, deployment} ->
        Containers.run_ready_actions(deployment, tenant: tenant)

        terminate_deployer(deployment_id)

      error ->
        terminate_on_error(error, data)
    end
  end

  # State: :error

  def handle_event(:enter, old_state, :deployment_failure, data) do
    %Data{deployment_id: deployment_id} = data

    Logger.info(
      "Entering :deployment_failure from state #{inspect(old_state)} for deployment #{deployment_id}",
      tag: "deployment_failure"
    )

    :keep_state_and_data
  end

  def handle_event(:internal, {:failure, reason}, :deployment_failure, data) do
    %Data{deployment_id: deployment_id} = data

    Logger.error("Failed deployment #{deployment_id} with reason #{inspect(reason)}",
      tag: "deployment_failure"
    )

    {:stop, {:error, reason}}
  end

  # Util functions

  defp terminate_on_error(error, data) do
    {:next_state, :deployment_failure, data, internal_event({:failure, error})}
  end

  defp terminate_deployer(deployment_id) do
    Logger.info("Terminating deployer process for deployment #{deployment_id}",
      tag: "terminating_deployment"
    )

    {:stop, :normal}
  end

  defp internal_event(payload) do
    {:next_event, :internal, payload}
  end
end
