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

defmodule Edgehog.Containers.Deployment.Orchestrator do
  @moduledoc """
  Orchestrator for all provisioner processes of a deployment.

  A deployment consists of multiple resources
  - a series of containers
  - the deployment itself

  All these resources have their own process that supervises the communication
  with the device, retrying when some error happens or querying astarte when
  triggers might be missing.

  This orchestrator is responsible for
  - spawning such provisioning processes
  - wait for readiness of the various resources
  - emit readiness of the whole deployment when each and every resource finishes
  - mark the deployment as failed when a resource reports a failure

  Children are not supervised nor cleaned up by this orchestrator: a child that
  crashes is ignored, and a child that gives up (e.g. the maximum number of
  retries was hit, the device went offline, or the provisioning timeout was hit)
  reports a failure through PubSub, which this orchestrator reacts to. Cleanup
  of the provisioning tree on failure is not handled here.
  """

  use GenServer, restart: :transient

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Deployment.Orchestrator.Core
  alias Edgehog.Containers.Deployment.Orchestrator.Registry, as: DeploymentOrchestratorRegistry
  alias Edgehog.Containers.Telemetry

  @test Mix.env() == :test

  @sup Edgehog.Containers.Deployment.Orchestrator.Supervisor

  # API

  @doc """
  Conducts the provisioning of a deployment.

  Starts the orchestrator for the given deployment under the
  `Edgehog.Containers.Deployment.Orchestrator.Supervisor` dynamic supervisor, which
  owns the whole provisioning tree of the deployment (its containers and their
  provisioners).

  The deployment orchestrator then:
  - spawns the provisioner processes of the deployment and its resources
  - waits for the readiness of each and every resource
  - emits the readiness of the whole deployment once all the resources are ready
  - marks the deployment as failed if a resource reports a failure

  If a deployment is already being conducted, the pid of the running orchestrator
  is returned and no duplicate orchestrator is started.

  Returns `{:ok, pid}` where `pid` is the orchestrator process, or
  `{:error, reason}`.
  """
  def conduct(deployment, tenant, opts \\ []) do
    args =
      opts
      |> Keyword.put(:deployment, deployment)
      |> Keyword.put(:tenant, tenant)

    child_spec = Supervisor.child_spec({__MODULE__, args}, id: deployment.id)

    with {:error, {:already_started, pid}} <- DynamicSupervisor.start_child(@sup, child_spec) do
      {:ok, pid}
    end
  end

  def start_link(args) do
    deployment = Keyword.fetch!(args, :deployment)

    GenServer.start_link(__MODULE__, args, name: name(deployment))
  end

  @doc """
  Returns the registered name for the orchestrator of a deployment.

  It accepts either an entire `%Edgehog.Containers.Deployment{}` resource, or
  just an ID.
  """
  def name(%Deployment{id: id}), do: {:via, Registry, {DeploymentOrchestratorRegistry, id}}
  def name(id), do: {:via, Registry, {DeploymentOrchestratorRegistry, id}}

  @doc """
  Returns the readiness topic the orchestrator will publish onto when the
  deployment and its children are ready.

  It accepts either an entire %Edgehog.Containers.Deployment{} resource, or just
  an ID.
  """
  def topic(%Deployment{id: id}), do: "deployments:ready:#{id}"
  def topic(id), do: "deployments:ready:#{id}"

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
    deployment = Keyword.fetch!(args, :deployment)
    tenant = Keyword.fetch!(args, :tenant)

    mode = Keyword.get(args, :mode, :auto)

    started_at = Telemetry.deployment_started(deployment)

    state = %{
      deployment: deployment,
      tenant: tenant,
      mode: mode,
      started_at: started_at
    }

    %{id: id} = deployment

    Core.log_orchestrator_started(id, mode)

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
        Core.log_resources_loaded(state.deployment.id)

        {:noreply, new_state, {:continue, :provision_deployments}}

      {:error, reason} ->
        Core.log_load_resources_failed(state.deployment.id, reason)

        fail_deployment(state)
    end
  end

  # This step of the initialization process provisions underlying resources
  @impl GenServer
  def handle_continue(:provision_deployments, state) do
    new_state = Core.provision(state)

    if Map.get(new_state, :provisioning_failed, false) do
      fail_deployment(new_state)
    else
      Core.log_provisioning_started(state.deployment.id)

      {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_continue(:maybe_ready, state) do
    ready? = Core.ready?(state)

    Core.log_readiness_check(state.deployment.id, ready?)

    if ready?,
      do: {:stop, :normal, state},
      else: {:noreply, state}
  end

  ## Infos

  @impl GenServer
  def handle_info({:ready, %Deployment{} = deployment}, state) do
    Core.log_deployment_ready(state.deployment.id)

    new_state = Core.deployment_ready(state, deployment)

    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  @impl GenServer
  def handle_info(
        %Phoenix.Socket.Broadcast{event: :ready, payload: %Container.Deployment{id: id}},
        state
      ) do
    Core.log_container_ready(state.deployment.id, id)

    new_state = Core.container_ready(id, state)

    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  @impl GenServer
  def handle_info({:failure, %Deployment{}}, state) do
    Core.log_deployment_failure(state.deployment.id)

    fail_deployment(state)
  end

  @impl GenServer
  def handle_info(
        %Phoenix.Socket.Broadcast{event: :failure, payload: %Container.Deployment{id: id}},
        state
      ) do
    Core.log_container_failure(state.deployment.id, id)

    fail_deployment(state)
  end

  @impl GenServer
  def terminate(:normal, state) do
    %{
      deployment: deployment,
      tenant: tenant,
      started_at: started_at
    } = state

    %{id: id} = deployment

    Core.log_orchestrator_completed(id)

    Telemetry.deployment_completed(deployment, started_at)

    readiness_topic = topic(deployment)

    event = %Phoenix.Socket.Broadcast{
      topic: readiness_topic,
      event: :ready,
      payload: deployment
    }

    Core.log_broadcasting_readiness(id, readiness_topic)

    # Broadcast readiness
    Phoenix.PubSub.broadcast(Edgehog.PubSub, readiness_topic, event)

    Core.log_running_ready_actions(id)

    # Run ready actions. This cannot raise, otherwise the orchestrator would
    # terminate abnormally even if the deployment was successfully provisioned.
    result =
      deployment
      |> Ash.Changeset.for_update(:run_ready_actions, %{})
      |> Ash.update(tenant: tenant)

    case result do
      {:ok, _deployment} ->
        :ok

      {:error, reason} ->
        Core.log_ready_actions_failed(id, reason)
    end

    Core.log_deployment_provisioned(id)

    :ok
  end

  @impl GenServer
  def terminate(_reason, _state), do: :ok

  ## Failure handling

  defp fail_deployment(state) do
    %{
      deployment: deployment,
      tenant: tenant,
      started_at: started_at
    } = state

    %{id: id} = deployment

    Core.log_provisioning_failed(id)

    Telemetry.deployment_failed(deployment, started_at)

    # Mark the deployment as timed out. This also publishes on the
    # deployments:timeout:id topic through the Ash notifier.
    deployment
    |> Ash.Changeset.for_update(:mark_as_timed_out, %{})
    |> Ash.update(tenant: tenant)

    readiness_topic = topic(deployment)

    event = %Phoenix.Socket.Broadcast{
      topic: readiness_topic,
      event: :failure,
      payload: deployment
    }

    # Broadcast readiness failure
    Phoenix.PubSub.broadcast!(Edgehog.PubSub, readiness_topic, event)

    {:stop, {:shutdown, :deployment_failed}, state}
  end
end
