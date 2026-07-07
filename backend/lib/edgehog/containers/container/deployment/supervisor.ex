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

defmodule Edgehog.Containers.Container.Deployment.Supervisor do
  @moduledoc """
  A supervisor for all provisioner processes for a container.

  A container consists of various resources.
  - an image
  - volumes
  - networks
  - ...

  All these resources have their own process that supervises the communication
  with the device, retrying when some error happens or querying astarte when
  triggers might be missing.

  This supervisor is responsible for
  - spawning such supervision processes
  - wait for readiness of the various resources
  - emit readiness of the whole container when each and every resource finishes

  It also handles retries and timeouts, emitting also failures when retrying did
  not succeed.
  """

  use GenServer, restart: :transient

  alias Container.Deployment.Supervisor.Registry, as: SupervisorRegistry
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Container.Deployment.Supervisor.Core
  alias Edgehog.Containers.DeviceMapping
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Volume

  require Logger

  @test Mix.env() == :test

  # API

  def supervise(container_deployment, deployment, tenant, opts \\ []) do
    opts
    |> Keyword.put(:container_deployment, container_deployment)
    |> Keyword.put(:deployment, deployment)
    |> Keyword.put(:tenant, tenant)
    |> start_link()
  end

  def start_link(args) do
    container_deployment = Keyword.fetch!(args, :container_deployment)

    GenServer.start_link(__MODULE__, args, name: name(container_deployment))
  end

  def name(%Container.Deployment{id: id}) do
    {:via, Registry, {SupervisorRegistry, id}}
  end

  # Test additional API
  # In test environment, allow to start the process with a message, so that the
  # test process can attach and monitor it
  if @test do
    def start(provisioner) do
      GenServer.cast(provisioner, :start)
    end

    @impl GenServer
    def handle_cast(:start, state) do
      {:noreply, state, {:continue, :load_resources}}
    end
  end

  # Callbacks

  @impl GenServer
  def init(args) do
    container_deployment = Keyword.fetch!(args, :container_deployment)
    deployment = Keyword.fetch!(args, :deployment)
    tenant = Keyword.fetch!(args, :tenant)

    mode = Keyword.get(args, :mode, :auto)

    state = %{
      container_deployment: container_deployment,
      deployment: deployment,
      tenant: tenant,
      state: :init,
      mode: mode,
      retries: 0
    }

    %{id: id} = container_deployment

    Logger.info("Subscribing to events on container deployment #{id}")
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "container_deployments:#{id}")

    {:ok, state, {:continue, :maybe_load_resources}}
  end

  ## Continues

  @impl GenServer
  def handle_continue(:maybe_load_resources, %{mode: :auto} = state) do
    {:noreply, state, {:continue, :load_resources}}
  end

  @impl GenServer
  def handle_continue(:maybe_load_resources, state) do
    {:noreply, state}
  end

  # This step of the initialization process loads all the resources and puts
  # them in the state
  @impl GenServer
  def handle_continue(:load_resources, state) do
    new_state = Core.load_resources(state)

    {:noreply, new_state, {:continue, :provision_deployments}}
  end

  # This step of the initialization process
  @impl GenServer
  def handle_continue(:provision_deployments, state) do
    new_state = Core.provision(state)

    timeout = timeout(state)

    {:noreply, new_state, timeout}
  end

  @impl GenServer
  def handle_continue(:maybe_ready, state) do
    %{
      container_deployment: container_deployment
    } = state

    %{id: id} = container_deployment

    timeout = timeout(state)

    if Core.ready?(state) do
      # Broadcast readiness
      Phoenix.PubSub.broadcast(
        Edgehog.PubSub,
        "ready:container_deployment:#{id}",
        {:ready, container_deployment}
      )

      # Terminate normally
      {:stop, :normal, state}
    else
      {:noreply, state, timeout}
    end
  end

  ## Infos

  @impl GenServer
  def handle_info({:ready, %Image.Deployment{}}, state) do
    new_state = Core.image_ready(state)

    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  @impl GenServer
  def handle_info({:ready, %Volume.Deployment{id: id}}, state) do
    new_state = Core.volume_ready(id, state)

    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  @impl GenServer
  def handle_info({:ready, %Network.Deployment{id: id}}, state) do
    new_state = Core.network_ready(id, state)

    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  @impl GenServer
  def handle_info({:ready, %DeviceMapping.Deployment{id: id}}, state) do
    new_state = Core.device_mapping_ready(id, state)

    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  @impl GenServer
  def handle_info({:ready, %Container.Deployment{}}, state) do
    new_state = Core.container_ready(state)

    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    state_ready? = Core.ready?(state)

    ready? =
      if state_ready?,
        do: "ready",
        else: "not ready"

    Logger.warning("""
    Container supervisor for container hit a timeout, the underlying resources were #{ready?}.

    The supervisor will now terminate, something went wrong.
    """)

    # TODO: check liveness and possibly restart processes instead of shutting
    # down
    {:stop, {:shutdown, :timeout_hit}, state}
  end

  defp timeout(_state) do
    to_timeout(minute: 10)
  end
end
