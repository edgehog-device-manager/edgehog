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

defmodule Edgehog.Containers.Deployment.Provisioner do
  @moduledoc """
  A deployment provisioner.

  Each and every time a deployment should be provisioned, it can be done through
  this Service. The provisioner sends the appropriate messages to the device and
  emits an event on topic `deployments:provisioning:id` event whenever
  deployment is present in the device.

  The provisioning flow can be described as follows:

  - start_link/1 called, init the process
  - The server subscribes to events on 'deployments:id' (id of the deployment
    deployment)
  - Core.send/2 is called, sending the appropriate messages to the device (see
    Core.send/1 docs for more info)

  Nice flow (everything goes ok)
  - Astarte triggers update the deployment deployment state, marking it as present or
    not present and emitting an event on the correct topic
  - The server reacts to the event, handles the message and emits an event on
    'ready:deployment:id' when the resource is ready
  - listening processes can react to this information

  Timeouts (something goes wrong)
  - Core.send/2 failed, maybe the device is offline, or there was some problem
    with astarte
  - an exponential backoff timeout is started
  - A :timeout hits the server, it retries to send the deployment information to the
    device
  """

  use GenServer, restart: :transient

  alias Deployment.Provisioner.Registry, as: ProvisionerRegistry
  alias Edgehog.Config
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Deployment.Provisioner.Core

  require Logger

  @test Mix.env() == :test
  @deployment_ready_states [:started, :stopped]

  # API

  def provision(deployment, tenant, opts \\ []) do
    opts
    |> Keyword.put(:deployment, deployment)
    |> Keyword.put(:tenant, tenant)
    |> start_link()
  end

  def start_link(args) do
    deployment = args |> Keyword.fetch!(:deployment) |> Ash.load!(:device)
    args = Keyword.put(args, :deployment, deployment)

    GenServer.start_link(__MODULE__, args, name: name(deployment))
  end

  @doc """
  Starts a provisioner for an application deployment, without linking it to the
  current process.

  See `start_link/1` docs for more information
  """
  def start(args) do
    deployment = args |> Keyword.fetch!(:deployment) |> Ash.load!(:device)
    args = Keyword.put(args, :deployment, deployment)

    GenServer.start(__MODULE__, args, name: name(deployment))
  end

  @doc """
  Returns the readiness topic the provisioner will publish onto when the resource
  is ready.

  it accepts either an entire %Edgehog.Containers.Deployment{} resource, or just
  an ID.
  """
  def topic(%Deployment{id: id}), do: "deployments:provisioning:#{id}"
  def topic(id), do: "deployments:provisioning:#{id}"

  def name(%Deployment{id: id}) do
    {:via, Registry, {ProvisionerRegistry, id}}
  end

  # Test additional API
  # In test environment, allow to run the process with a message, so that the
  # test process can attach and monitor it
  if @test do
    def run(provisioner) do
      GenServer.cast(provisioner, :run)
    end

    @impl GenServer
    def handle_cast(:run, state) do
      {:noreply, state, {:continue, :check_deployment_state}}
    end
  end

  #### Callbacks

  @impl GenServer
  def init(args) do
    deployment = Keyword.fetch!(args, :deployment)
    tenant = Keyword.fetch!(args, :tenant)

    mode = Keyword.get(args, :mode, :auto)

    %{id: id, device: %{id: device_id, online: device_online?}} =
      deployment

    state = %{
      deployment: deployment,
      tenant: tenant,
      device_online?: device_online?,
      state: :init,
      mode: mode,
      retries: 0
    }

    Logger.info("Subscribing to events on deployment #{id}")
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "deployments:#{id}")

    Logger.info(
      "Subscribing to status events of device #{device_id} for (application) deployment #{id}"
    )

    Phoenix.PubSub.subscribe(Edgehog.PubSub, "devices:offline:#{device_id}")

    Logger.debug(
      "Device #{device_id} is currently #{if device_online?, do: "online", else: "offline"}"
    )

    {:ok, state, {:continue, :maybe_start}}
  end

  @impl GenServer
  def handle_continue(:maybe_start, %{mode: :auto} = state) do
    next_step = {:noreply, state, {:continue, :check_deployment_state}}
    maybe_early_terminate(state, next_step)
  end

  @impl GenServer
  def handle_continue(:maybe_start, %{mode: :manual} = state) do
    next_step = {:noreply, state}
    maybe_early_terminate(state, next_step)
  end

  @impl GenServer
  def handle_continue(
        :check_deployment_state,
        %{deployment: deployment} = state
      ) do
    # Here we have to compute readiness of the single `deployment` resource. We
    # cannot delegate this to the `is_ready` calculation as it computes global
    # readiness for the public.
    if ready?(deployment) do
      new_state = Map.put(state, :deployment, deployment)
      {:stop, :normal, new_state}
    else
      {:noreply, state, {:continue, :send}}
    end
  end

  @impl GenServer
  def handle_continue(:send, state), do: maybe_send(state)

  @impl GenServer
  def handle_continue(:maybe_ready, state) do
    %{deployment: deployment} = state

    timeout = Core.timeout(state)

    # Again, we cannot use the `is_ready` calculation
    if ready?(deployment),
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
    %{deployment: deployment, tenant: tenant} = state

    deployment = Core.reconcile(deployment, tenant: tenant)

    case deployment do
      :not_found ->
        maybe_send(state)

      {:ok, deployment} ->
        # Reconciliation updated the deployment, just update the state as a new
        # message will come in the queue
        new_state = Map.put(state, :deployment, deployment)

        # This just in case the message is not actually there, but I'd consider it a bug
        timeout = Core.timeout(state)

        {:noreply, new_state, timeout}
    end
  end

  # We get the deployment from the broadcast, which is in the :payload ->
  # :data section. This deployment is more recent, as it comes from an
  # update in the database.
  @impl GenServer
  def handle_info(%Phoenix.Socket.Broadcast{payload: %{data: %Deployment{} = deployment}}, state) do
    new_state = Map.put(state, :deployment, deployment)

    # check readiness, maybe terminate
    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  @impl GenServer
  def handle_info(%Phoenix.Socket.Broadcast{topic: "devices:offline:" <> _id}, old_state) do
    new_state = Map.put(old_state, :device_online?, false)

    {:stop, {:shutdown, :device_offline}, new_state}
  end

  # NOTICE: we crash on messages that do not come from the notification system for the correct topic

  @impl GenServer
  def terminate(:normal, state) do
    %{
      deployment: %{id: id, device_id: device_id} = deployment
    } = state

    topic = topic(deployment)

    Phoenix.PubSub.broadcast(Edgehog.PubSub, topic, {:ready, deployment})

    # Unsubscribe from events, we're terminating
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "deployments:#{id}")
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
  end

  @impl GenServer
  def terminate({:shutdown, :device_offline}, state) do
    %{
      deployment: %{id: id, device_id: device_id}
    } = state

    Logger.info("""
    Device #{device_id} went offline. Provisioner for (application) deployment #{id} terminating.
    """)

    # Unsubscribe from events, we're terminating
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "deployments:#{id}")
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
  end

  @impl GenServer
  def terminate(reason, state) do
    %{
      deployment: %{id: id, device: %{id: device_id}}
    } = state

    Logger.warning(
      """
      Unexpectedly terminating provisioner for (application) deployment #{id} on device #{device_id}.
      Reason: #{inspect(reason)}
      """,
      reason: reason,
      provisioner_state: state
    )
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

  # Sends the deployment, without asking any questions. To check for
  # retries, use `maybe_send`.
  defp send(state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    new_state =
      deployment
      |> Core.send(tenant: tenant)
      |> maybe_update_state_on_send(state)

    timeout = Core.timeout(new_state)

    {:noreply, new_state, timeout}
  end

  # if the operation was successful, update the state to sent, log the error otherwise.
  defp maybe_update_state_on_send(:ok, state) do
    Map.put(state, :state, :sent)
  end

  defp maybe_update_state_on_send(error, state) do
    %{deployment: %{id: id}} = state

    Logger.warning(
      "Error while sending the deployment #{id}: #{inspect(error)}. The operation will be retried shortly."
    )

    state
  end

  # Returns an early stop tuple if the device is offline, otherwise continues with
  # the given `next_step`
  defp maybe_early_terminate(%{device_online?: device_online?} = state, next_step) do
    if device_online? do
      next_step
    else
      {:stop, {:shutdown, :device_offline}, state}
    end
  end

  # Update the state to increment the number of retries
  defp increase_retries(state) do
    Map.update!(state, :retries, &Kernel.+(&1, 1))
  end

  defp ready?(deployment) do
    %{state: state} = deployment

    state in @deployment_ready_states
  end
end
