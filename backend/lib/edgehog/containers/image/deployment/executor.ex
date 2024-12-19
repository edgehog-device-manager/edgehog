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

defmodule Edgehog.Containers.Image.Deployment.Executor do
  @moduledoc false

  use GenStateMachine, restart: :transient, callback_mode: [:handle_event_function, :state_enter]

  alias __MODULE__, as: Data
  alias Edgehog.Containers
  alias Edgehog.Devices
  alias Edgehog.PubSub

  require Logger

  defstruct [
    :tenant,
    :deployment
  ]

  def start_link(args) do
    name = args[:name] || __MODULE__

    GenStateMachine.start_link(__MODULE__, args, name: name)
  end

  @impl GenStateMachine
  def init(opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    data = %Data{
      tenant: tenant,
      deployment: deployment
    }

    if opts[:wait_for_start_execution] do
      # Use this to manually start the executor in tests
      {:ok, :wait_for_start_execution, data}
    else
      {:ok, :initialization, data, internal_event(:init_data)}
    end
  end

  # State: initialization

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :initialization, data) do
    %{deployment: deployment} = data

    Logger.info("Image Deployment #{deployment.id}: entering :initialization state")

    :keep_state_and_data
  end

  def handle_event(:internal, :init_data, :initialization, data) do
    %{deployment: deployment} = data

    PubSub.subscribe_to_events_for(deployment)

    {:keep_state_and_data, internal_event(:init_device)}
  end

  @impl GenStateMachine
  def handle_event(:internal, :init_device, :initialization, data) do
    %{deployment: deployment, tenant: tenant} = data

    try do
      deployment = Ash.load!(deployment, [:device, :image])

      _ = Devices.send_create_image_request!(deployment.device, deployment.image, tenant: tenant)

      _ = Containers.image_deployment_sent!(deployment, tenant: tenant)

      {:next_state, :sent, data}
    catch
      # TODO: different errors should lead to different error states, some should be recoverable, others not
      error -> terminate_on_error(error, data)
    end
  end

  # State: sent

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :sent, data) do
    %Data{deployment: deployment} = data

    Logger.info("Image Deployment #{deployment.id}: entering :sent state")

    :keep_state_and_data
  end

  @impl GenStateMachine
  def handle_event(:info, :available, :sent, data) do
    %{deployment: deployment, tenant: tenant} = data

    try do
      _ = Containers.image_deployment_unpulled!(deployment, tenant: tenant)

      {:stop, :normal}
    catch
      error -> terminate_on_error(error, data)
    end
  end

  # Helper functions

  defp internal_event(payload) do
    {:next_event, :internal, payload}
  end

  defp terminate_on_error(error, data) do
    %{deployment: deployment} = data

    Logger.error("Terminating executor process for deployment #{deployment.id} for error: #{inspect(error)}")

    {:stop, :normal}
  end
end
