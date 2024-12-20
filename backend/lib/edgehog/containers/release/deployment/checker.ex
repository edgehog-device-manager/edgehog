#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.Release.Deployment.Checker do
  @moduledoc false

  use GenStateMachine, restart: :transient, callback_mode: [:handle_event_function, :state_enter]

  alias __MODULE__, as: Data
  alias Edgehog.Containers
  alias Edgehog.PubSub

  require Logger

  defstruct [
    :tenant,
    :deployment,
    :networks,
    :containers,
    :images
  ]

  def start_link(args) do
    name = args[:name] || __MODULE__

    GenStateMachine.start_link(__MODULE__, args, name: name)
  end

  @impl GenStateMachine
  def init(opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)
    networks = Keyword.fetch!(opts, :networks)
    containers = Keyword.fetch!(opts, :containers)
    images = Keyword.fetch!(opts, :images)

    data = %Data{
      tenant: tenant,
      deployment: deployment,
      networks: networks,
      containers: containers,
      images: images
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

  # State: initialization

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :initialization, data) do
    %{deployment: deployment} = data

    Logger.info("Release Deployment #{deployment.id}: entering :initialization state")

    :keep_state_and_data
  end

  def handle_event(:internal, :init_data, :initialization, data) do
    %{deployment: deployment, containers: containers, networks: networks, images: images} = data

    Enum.each(
      [deployment | containers ++ networks ++ containers ++ images],
      &PubSub.subscribe_to_events_for/1
    )

    {:next_state, :check_images, data}
  end

  # State: check images

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :check_images, data) do
    %{images: images, deployment: deployment} = data

    Logger.info("Release Deployment #{deployment.id}: entering :check_images state")

    if images == [],
      do: {:next_state, :check_networks, data},
      else: :keep_state_and_data
  end

  def handle_event(:info, {:available_image, image_id}, :check_images, data) do
    %{images: images} = data

    # drop an image if recived
    new_images = Enum.reject(images, fn image -> image.id == image_id end)
    new_data = Map.put(data, :images, new_images)

    if new_images == [],
      do: {:next_state, :check_networks, new_data},
      else: {:keep_state, new_data}
  end

  # State: check networks

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :check_networks, data) do
    %{networks: networks, deployment: deployment} = data

    Logger.info("Release Deployment #{deployment.id}: entering :check_networks state")

    if networks == [],
      do: {:next_state, :check_containers, data},
      else: :keep_state_and_data
  end

  def handle_event(:info, {:available_network, network_id}, :check_networks, data) do
    %{networks: networks} = data

    # drop a network if recived
    new_networks = Enum.reject(networks, fn network -> network.id == network_id end)
    new_data = Map.put(data, :networks, new_networks)

    if new_networks == [],
      do: {:next_state, :check_containers, new_data},
      else: {:keep_state, new_data}
  end

  # State: check containers

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :check_containers, data) do
    %{containers: containers, deployment: deployment} = data

    Logger.info("Release Deployment #{deployment.id}: entering :check_containers state")

    if containers == [],
      do: {:next_state, :check_deployment, data},
      else: :keep_state_and_data
  end

  def handle_event(:info, {:available_container, container_id}, :check_containers, data) do
    %{containers: containers} = data

    # drop a container if recived
    new_containers = Enum.reject(containers, fn container -> container.id == container_id end)
    new_data = Map.put(data, :containers, new_containers)

    if new_containers == [],
      do: {:next_state, :check_deployment, new_data},
      else: {:keep_state, new_data}
  end

  # State: check deployment

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :check_containers, data) do
    %{deployment: deployment} = data

    Logger.info("Release Deployment #{deployment.id}: entering :check_deployment state")

    :keep_state_and_data
  end

  def handle_event(:info, :deployment_available, :check_deployment, data) do
    %{deployment: deployment} = data

    PubSub.publish!(:available_deployment, deployment)
    _ = Containers.run_ready_actions!(deployment)

    {:stop, :normal}
  end

  # Helper functions

  defp internal_event(payload) do
    {:next_event, :internal, payload}
  end
end
