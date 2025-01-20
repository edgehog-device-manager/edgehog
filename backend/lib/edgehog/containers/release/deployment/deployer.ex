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

defmodule Edgehog.Containers.Release.Deployment.Deployer do
  @moduledoc false
  use GenStateMachine, restart: :transient, callback_mode: [:handle_event_function, :state_enter]

  alias __MODULE__, as: Data
  alias Edgehog.Containers
  alias Edgehog.PubSub

  require Logger

  defstruct [
    :tenant,
    :deployment,
    :release,
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
    deployment = Keyword.fetch!(opts, :deployment)

    data = %Data{
      tenant: deployment.tenant_id,
      deployment: deployment,
    }

    if opts[:wait_for_start_execution] do
      # Use this to manually start the executor in tests
      {:ok, :wait_for_start_execution, data}
    else
      {:ok, :init, data, internal_event(:init_data)}
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

  # State: :init

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :init, data) do
    %{deployment: deployment} = data

    Logger.info("Release Deployment #{deployment.id}: entering :init state")

    :keep_state_and_data
  end

  def handle_event(:internal, :init_data, :init, data) do
    %{deployment: deployment} = data

    case Ash.load(deployment, [device: [], release: [containers: [:image], networks: []]]) do
      {:ok, deployment} ->
        release = deployment.release
        containers = release.containers
        networks = release.networks
        images = containers |> Enum.map(& &1.image)

        new_data = Enum.into(data, %{containers: containers, networks: networks, images: images})
        {:new_state, :send_images, new_data}

        {:error, error} ->
        # DB error, log and stop
    end
  end
  # State: :send_images :internal
  # State: :check_images
  # State: :send_networks :internal
  # State: :check_networks
  # State: :send_containers :internal
  # State: :check_containers

  # Helpers
  defp terminate_on_error(deployment, error) do
    Logger.error("Deployer for #{deployment.id} terminated on error: #{inspect(error)}")

    {:stop, :normal}
  end
end
