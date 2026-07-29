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

defmodule Edgehog.Containers.Container.Deployment.Provisioner do
  @moduledoc """
  A container deployment provisioner.

  Each and every time an container should be deployed, it can be done through this
  provisioner. The provisioner sends the appropriate messages to the device and
  emits a `ready:container_deployments:id` event whenever container is present in the
  device.

  The provisioning flow can be described as follows:

  - start_link/1 called, init the process
  - The server subscribes to events on 'container_deployments:id' (id of the container
    deployment)
  - Core.send/2 is called, sending the appropriate messages to the device (see
    Core.send/1 docs for more info)

  Nice flow (everything goes ok)
  - Astarte triggers update the container deployment state, marking it as present or
    not present and emitting an event on the correct topic
  - The server reacts to the event, handles the message and emits an event on
    'ready:container_deployment:id' when the resource is ready
  - listening processes can react to this information

  Timeouts (something goes wrong)
  - Core.send/2 failed, maybe the device is offline, or there was some problem
    with astarte
  - an exponential backoff timeout is started
  - A :timeout hits the server, it retries to send the container information to the
    device
  """

  use GenServer, restart: :transient

  alias Edgehog.Config
  alias Edgehog.Containers.Container.Deployment
  alias Edgehog.Containers.Container.Deployment.Provisioner.Core

  require Logger

  @test Mix.env() == :test
  @container_deployment_ready_states [:received, :device_created, :stopped, :running]

  #### API

  @doc """
  Starts the provisioner of an container deployment.

  Equivalent to starting the provisioner through `start_link/1` with opts
  ```
  [
    container_deployment: container_deployment,
    deployment: deployment,
    tenant: tenant
  ]
  ```

  See `start_link/1` docs for more information.
  """
  def provision(container_deployment, deployment, tenant, opts \\ []) do
    opts
    |> Keyword.put(:container_deployment, container_deployment)
    |> Keyword.put(:deployment, deployment)
    |> Keyword.put(:tenant, tenant)
    |> start_link()
  end

  @doc """
  Starts a provisioner for an container deployment.

  A provision for this resource follows the following flow:

  - checks that the resource is not ready already (i.e., the device never received it).
  - tries to send the deployment information to astarte (calling `&Devices.send_container_deployment/2`)
  - if an unrecoverable error occurs, broadcasts a failure on the `topic/1` topic.
  - if successful, waits for events on the container deployment itself.

  - if a trigger reaches edgehog, it changes a property in the container deployment resource, emitting an event for the provsioner.
  - the provisioner understands that the container is ready, it then exits successfully.

  - if the reconciler has no messages incoming after a timer defined through the `timeout/1` function:
    + checks for readiness of the resource, maybe we just missed the message
    + queries astarte, maybe the trigger was missing
    + retries to send the message to the device.
    + loops with a new timeout set by the `timeout/1` function.
  """
  def start_link(args) do
    container_deployment = Keyword.fetch!(args, :container_deployment)

    GenServer.start_link(__MODULE__, args, name: name(container_deployment))
  end

  @doc """
  Returns the readiness topic the provisioner will publish onto when the resource is ready.

  it accepts either an entire %Edgehog.Containers.Container.Deployment{} resource, or just the ID.
  """
  def topic(%Deployment{id: id}), do: "container_deployments:provisioning:#{id}"
  def topic(id), do: "container_deployments:provisioning:#{id}"

  def name(%Deployment{id: id}) do
    {:via, Registry, {Container.Deployment.Provisioner.Registry, id}}
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
      {:noreply, state, {:continue, :check_deployment_state}}
    end
  end

  #### Callbacks

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

    {:ok, state, {:continue, :maybe_start}}
  end

  @impl GenServer
  def handle_continue(:maybe_start, %{mode: :auto} = state) do
    {:noreply, state, {:continue, :check_deployment_state}}
  end

  @impl GenServer
  def handle_continue(:maybe_start, %{mode: :manual} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_continue(
        :check_deployment_state,
        %{container_deployment: container_deployment} = state
      ) do
    container_deployment =
      Ash.load!(container_deployment, :is_ready, tenant: container_deployment.tenant_id)

    if container_deployment.is_ready do
      new_state = Map.put(state, :container_deployment, container_deployment)
      {:stop, :normal, new_state}
    else
      {:noreply, state, {:continue, :send}}
    end
  end

  @impl GenServer
  def handle_continue(:send, state), do: send(state)

  @impl GenServer
  def handle_continue(:maybe_ready, state) do
    %{container_deployment: container_deployment} = state

    timeout = Core.timeout(state)

    # Here we have to compute readiness of the single `container deployment`
    # resource. We cannot delegate this to the `is_ready` calculation as it
    # computes global readiness for the public.
    if ready?(container_deployment),
      do: {:stop, :normal, state},
      else: {:noreply, state, timeout}
  end

  # We were not able to send the message to the device. retry
  @impl GenServer
  def handle_info(:timeout, %{state: :init} = state), do: maybe_send(state)

  # We sent the message to the device, but no trigger came back.
  # 1. Reconcile with astarte
  # 2. if still nothing has come back, retry to send
  @impl GenServer
  def handle_info(:timeout, %{state: :sent} = state) do
    %{container_deployment: container_deployment, tenant: tenant} = state

    container_deployment = Core.reconcile(container_deployment, tenant: tenant)

    case container_deployment do
      :not_found ->
        maybe_send(state)

      {:ok, container_deployment} ->
        # Reconciliation updated the container deployment, just update the state as a
        # new message will come in the queue
        new_state = Map.put(state, :container_deployment, container_deployment)

        # This just in case the message is not actually there, but I'd consider it a bug
        timeout = Core.timeout(state)

        {:noreply, new_state, timeout}
    end
  end

  # We get the container deployment from the broadcast, which is in the :payload ->
  # :data section. This container deployment is more recent, as it comes from an
  # update in the database.
  @impl GenServer
  def handle_info(%Phoenix.Socket.Broadcast{payload: %{data: container_deployment}}, state) do
    new_state = Map.put(state, :container_deployment, container_deployment)

    # check readiness, maybe terminate
    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  # NOTICE: we crash on messages that do not come from the notification system for the correct topic

  @impl GenServer
  def terminate(:normal, state) do
    %{container_deployment: container_deployment} = state

    %{id: id} = container_deployment

    topic = topic(container_deployment)

    Phoenix.PubSub.broadcast(Edgehog.PubSub, topic, {:ready, container_deployment})

    # Unsubscribe from events, we're terminating
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "container_deployments:#{id}")
  end

  #### Helper functions

  # Send the container if the number of retries does not exceed the max number of
  # retries.
  defp maybe_send(state) do
    retries = Map.fetch!(state, :retries)
    max_retries = Config.max_retries!()

    if retries < max_retries do
      state
      |> increase_retries()
      |> send()
    else
      {:stop, {:shutdown, :max_retries}, state}
    end
  end

  # Sends the container deployment, without asking any questions. To check for
  # retries, use `maybe_send`.
  defp send(state) do
    %{
      container_deployment: container_deployment,
      deployment: deployment,
      tenant: tenant
    } = state

    new_state =
      container_deployment
      |> Core.send(tenant: tenant, deployment: deployment)
      |> maybe_update_state_on_send(state)

    timeout = Core.timeout(new_state)

    {:noreply, new_state, timeout}
  end

  # if the operation was successful, update the state to sent, log the error otherwise.
  defp maybe_update_state_on_send(:ok, state) do
    Map.put(state, :state, :sent)
  end

  defp maybe_update_state_on_send(error, state) do
    %{container_deployment: %{id: id}} = state

    Logger.warning(
      "Error while sending the deployment #{id}: #{inspect(error)}. The operation will be retried shortly."
    )

    state
  end

  # Update the state to increment the number of retries
  defp increase_retries(state) do
    Map.update!(state, :retries, &Kernel.+(&1, 1))
  end

  defp ready?(container_deployment) do
    %{state: state} = container_deployment

    state in @container_deployment_ready_states
  end
end
