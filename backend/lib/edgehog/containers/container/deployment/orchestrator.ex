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

defmodule Edgehog.Containers.Container.Deployment.Orchestrator do
  @moduledoc """
  Orchestrator for all the provisioner processes of a container.

  A container consists of various resources.
  - an image
  - volumes
  - networks
  - ...

  All these resources have their own provisioner process that supervises the
  communication with the device, retrying when some error happens or querying
  astarte when triggers might be missing.

  This orchestrator is responsible for
  - spawning such provisioning processes
  - wait for readiness of the various resources
  - emit readiness of the whole container when each and every resource finishes
  - emit a failure of the whole container when a resource reports a failure

  Children are not supervised nor cleaned up by this orchestrator: a child that
  crashes is ignored, and a child that gives up (e.g. the maximum number of
  retries was hit, the device went offline, or the provisioning timeout was hit)
  reports a failure through PubSub, which this orchestrator reacts to.
  """

  use GenServer, restart: :transient

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Container.Deployment.Orchestrator.Core
  alias Edgehog.Containers.Container.Deployment.Orchestrator.Registry, as: ContainerRegistry
  alias Edgehog.Containers.DeviceMapping
  alias Edgehog.Containers.DeviceRequest
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Volume

  require Logger

  @test Mix.env() == :test

  @sup Edgehog.Containers.Container.Deployment.Orchestrator.Supervisor

  # API

  @doc """
  Conducts the provisioning of a container deployment.

  Starts the orchestrator for the given container deployment under the
  `Edgehog.Containers.Container.Deployment.Orchestrator.Supervisor` dynamic
  supervisor, which owns the whole provisioning tree of the container (its image,
  volumes, networks, device mappings, device requests and their provisioners).

  The container orchestrator then:
  - spawns the provisioner processes of the container deployment and its
    resources
  - waits for the readiness of each and every resource
  - emits the readiness of the whole container once all the resources are ready
  - marks the container deployment as failed if a resource reports a failure

  If the container deployment is already being conducted, the pid of the running
  orchestrator is returned and no duplicate orchestrator is started.

  Returns `{:ok, pid}` where `pid` is the orchestrator process, or
  `{:error, reason}`.
  """
  def conduct(container_deployment, deployment, tenant, opts \\ []) do
    args =
      opts
      |> Keyword.put(:container_deployment, container_deployment)
      |> Keyword.put(:deployment, deployment)
      |> Keyword.put(:tenant, tenant)

    child_spec = Supervisor.child_spec({__MODULE__, args}, id: container_deployment.id)

    with {:error, {:already_started, pid}} <- DynamicSupervisor.start_child(@sup, child_spec) do
      {:ok, pid}
    end
  end

  def start_link(args) do
    container_deployment = Keyword.fetch!(args, :container_deployment)

    GenServer.start_link(__MODULE__, args, name: name(container_deployment))
  end

  @doc """
  Returns the readiness topic the orchestrator will publish onto when the
  resource and its children are ready.

  It accepts either an entire %Edgehog.Containers.Container.Deployment{}
  resource, or just the ID.
  """
  def topic(%Container.Deployment{id: id}), do: "container_deployments:ready:#{id}"
  def topic(id), do: "container_deployments:ready:#{id}"

  def name(%Container.Deployment{id: id}) do
    {:via, Registry, {ContainerRegistry, id}}
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
      mode: mode
    }

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
    case Core.load_resources(state) do
      {:ok, new_state} ->
        Logger.debug(
          "Loading resources for container deployment #{state.container_deployment.id}"
        )

        {:noreply, new_state, {:continue, :provision_deployments}}

      {:error, reason} ->
        Logger.error("""
        Error while loading the resources for container deployment #{state.container_deployment.id}: #{inspect(reason)}.

        The container deployment will be marked as failed.
        """)

        fail_container(state)
    end
  end

  # This step of the initialization process provisions all underlying resources
  @impl GenServer
  def handle_continue(:provision_deployments, state) do
    new_state = Core.provision(state)

    if Map.get(new_state, :provisioning_failed, false) do
      fail_container(new_state)
    else
      {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_continue(:maybe_ready, state) do
    %{
      container_deployment: container_deployment
    } = state

    if Core.ready?(state) do
      topic = topic(container_deployment)

      event = %Phoenix.Socket.Broadcast{
        topic: topic,
        event: :ready,
        payload: container_deployment
      }

      # Broadcast readiness
      Phoenix.PubSub.broadcast(Edgehog.PubSub, topic, event)

      # Terminate normally
      {:stop, :normal, state}
    else
      {:noreply, state}
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
  def handle_info({:ready, %DeviceRequest.Deployment{id: id}}, state) do
    new_state = Core.device_request_ready(id, state)

    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  @impl GenServer
  def handle_info({:ready, %Container.Deployment{}}, state) do
    new_state = Core.container_ready(state)

    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  @impl GenServer
  def handle_info({:failure, _deployment}, state) do
    Logger.warning(
      "A provisioner for container deployment #{state.container_deployment.id} gave up. Failing the container deployment."
    )

    fail_container(state)
  end

  ## Terminate

  defp fail_container(state) do
    %{
      container_deployment: container_deployment
    } = state

    %{id: id} = container_deployment

    Logger.warning("Container deployment #{id} provisioning failed.")

    topic = topic(container_deployment)

    event = %Phoenix.Socket.Broadcast{
      topic: topic,
      event: :failure,
      payload: container_deployment
    }

    # Broadcast failure
    Phoenix.PubSub.broadcast!(Edgehog.PubSub, topic, event)

    {:stop, {:shutdown, :container_failed}, state}
  end
end
