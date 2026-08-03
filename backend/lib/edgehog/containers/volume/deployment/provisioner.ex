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

defmodule Edgehog.Containers.Volume.Deployment.Provisioner do
  @moduledoc """
  A volume deployment provisioner.

  Each and every time a volume should be deployed, it can be done through this
  provisioner. The provisioner sends the appropriate messages to the device and
  emits a `ready:volume_deployments:id` event whenever volume is present in the
  device.

  The provisioning flow can be described as follows:

  - start_link/1 is called, initializing the process and subscribing to the
    events emitted on `volume_deployments:<id>` (id of the volume deployment)
  - if the volume deployment is already ready, the provisioner terminates normally
    right away, broadcasting readiness
  - otherwise the appropriate messages are sent to the device through the
    `Core` module (see `Core.send/1` docs for more info)

  Nice flow (everything goes ok)
  - Astarte triggers update the volume deployment state, marking it as present or
    not present and emitting an event on the correct topic
  - The server reacts to the event, handles the message and emits an event on
    'ready:volume_deployment:id' when the resource is ready
  - listening processes can react to this information

  Timeouts (something goes wrong)
  - `Core.send/1` failed, maybe the device is offline, or there was some
    problem with astarte
  - an exponential backoff timeout is started
  - A :timeout hits the server, it retries to send the volume information to the
    device
  """

  use GenServer, restart: :transient

  alias Edgehog.Config
  alias Edgehog.Containers.Volume.Deployment
  alias Edgehog.Containers.Volume.Deployment.Provisioner.Core

  require Logger

  @test Mix.env() == :test
  @sup Edgehog.Containers.Volume.Provisioner.Supervisor

  #### API

  @doc """
  Starts the provisioner of a volume deployment.

  Starts the right process trough the #{inspect(@sup)} dynamic supervisor.
  When creating the link, the server checks a registry to know whether the
  corresponding process is already up and running. Check `start_link/1` docs for
  more.
  """
  def provision(volume_deployment, deployment, tenant, opts \\ []) do
    args =
      opts
      |> Keyword.put(:volume_deployment, volume_deployment)
      |> Keyword.put(:deployment, deployment)
      |> Keyword.put(:tenant, tenant)

    child_spec = Supervisor.child_spec({__MODULE__, args}, id: volume_deployment.id)

    with {:error, {:already_started, pid}} <- DynamicSupervisor.start_child(@sup, child_spec) do
      {:ok, pid}
    end
  end

  @doc """
  Starts a provisioner for a volume deployment.

  A provision for this resource follows the following flow:

  - checks that the resource is not ready already (i.e., the device never received it).
  - tries to send the deployment information to astarte (calling `&Devices.send_volume_deployment/2`)
  - if an unrecoverable error occurs, broadcasts a failure on the `topic/1` topic.
  - if successful, waits for events on the volume deployment itself.

  - if a trigger reaches edgehog, it changes a property in the volume deployment resource, emitting an event for the provsioner.
  - the provisioner understands that the volume is ready, it then exits successfully.

  - if the reconciler has no messages incoming after a timer defined trough the `timeout/1` function:
    + checks for readiness of the resource, maybe we just missed the message
    + queries astarte, maybe the trigger was missing
    + retries to send the message to the device.
    + loops with a new timeout set by the `timeout/1` function.
  """
  def start_link(args) do
    volume_deployment = args |> Keyword.fetch!(:volume_deployment) |> Ash.load!(:device)
    args = Keyword.put(args, :volume_deployment, volume_deployment)

    GenServer.start_link(__MODULE__, args, name: name(volume_deployment))
  end

  @doc """
  Starts a provisioner for a volume deployment, without linking it to the
  current process.

  See `start_link/1` docs for more information
  """
  def start(args) do
    volume_deployment = args |> Keyword.fetch!(:volume_deployment) |> Ash.load!(:device)
    args = Keyword.put(args, :volume_deployment, volume_deployment)

    GenServer.start(__MODULE__, args, name: name(volume_deployment))
  end

  def name(%Deployment{id: id}) do
    {:via, Registry, {Volume.Deployment.Provisioner.Registry, id}}
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
    volume_deployment = Keyword.fetch!(args, :volume_deployment)
    deployment = Keyword.fetch!(args, :deployment)
    tenant = Keyword.fetch!(args, :tenant)

    mode = Keyword.get(args, :mode, :auto)

    %{id: id, device: %{id: device_id, online: device_online?}} =
      volume_deployment

    state = %{
      volume_deployment: volume_deployment,
      deployment: deployment,
      device_online?: device_online?,
      tenant: tenant,
      state: :init,
      mode: mode,
      retries: 0
    }

    Logger.info("Subscribing to events on volume deployment #{id}")
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "volume_deployments:#{id}")

    Logger.info("Subscribing to status events of device #{device_id} for volume deployment #{id}")
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "devices:offline:#{device_id}")

    Logger.debug(
      "Device #{device_id} is currently #{if device_online?, do: "online", else: "offline"}"
    )

    # If the provisioning does not complete within this deadline, the
    # provisioner gives up and broadcasts a failure that the orchestrator reacts
    # to
    deadline = Config.deployment_provisioning_timeout!()
    Process.send_after(self(), :give_up, deadline)

    {:ok, state, {:continue, :maybe_start}}
  end

  @impl GenServer
  def handle_continue(:maybe_start, %{mode: :auto} = state) do
    next_step = {:noreply, state, {:continue, :check_deployment_state}}
    Core.maybe_early_terminate(state, next_step)
  end

  @impl GenServer
  def handle_continue(:maybe_start, %{mode: :manual} = state) do
    next_step = {:noreply, state}
    Core.maybe_early_terminate(state, next_step)
  end

  @impl GenServer
  def handle_continue(:check_deployment_state, %{volume_deployment: volume_deployment} = state) do
    volume_deployment =
      Ash.load!(volume_deployment, :is_ready, tenant: volume_deployment.tenant_id)

    if volume_deployment.is_ready do
      new_state = Map.put(state, :volume_deployment, volume_deployment)
      {:stop, :normal, new_state}
    else
      {:noreply, state, {:continue, :send}}
    end
  end

  @impl GenServer
  def handle_continue(:send, state), do: Core.send(state)

  # We were not able to send the message to the device. retry
  @impl GenServer
  def handle_info(:timeout, %{state: :init} = state), do: Core.send(state)

  # We sent the message to the device, but no trigger came back.
  # 1. Reconcile with astarte
  # 2. if still nothing has come back, retry to send
  @impl GenServer
  def handle_info(:timeout, %{state: :sent} = state) do
    %{volume_deployment: volume_deployment, tenant: tenant} = state

    volume_deployment = Core.reconcile(volume_deployment, tenant: tenant)

    case volume_deployment do
      :not_found ->
        Core.maybe_send(state)

      {:ok, volume_deployment} ->
        # Reconciliation updated the volume deployment, just update the state as a
        # new message will come in the queue
        new_state = Map.put(state, :volume_deployment, volume_deployment)

        # This just in case the message is not actually there, but I'd consider it a bug
        timeout = Core.timeout(state)

        {:noreply, new_state, timeout}
    end
  end

  # We get the volume deployment from the broadcast, which is in the :payload ->
  # :data section. This volume deployment is more recent, as it comes from an
  # update in the database.
  @impl GenServer
  def handle_info(
        %Phoenix.Socket.Broadcast{payload: %{data: %Deployment{} = volume_deployment}},
        state
      ) do
    # We can publish on readiness topic.
    id = volume_deployment.id

    Phoenix.PubSub.broadcast(
      Edgehog.PubSub,
      "ready:volume_deployments:#{id}",
      {:ready, volume_deployment}
    )

    new_state = Map.put(state, :volume_deployment, volume_deployment)

    # Somewhere the volume has been marked in some state (pulled/unpulled). For
    # now we can just shutdown gracefully
    {:stop, :normal, new_state}
  end

  # The volume deployment provisioning deadline was hit, give up and broadcast a
  # failure so that the orchestrator can react
  @impl GenServer
  def handle_info(:give_up, state) do
    Logger.warning("""
    Volume deployment #{state.volume_deployment.id} provisioning timed out. Giving up.
    """)

    {:stop, {:shutdown, :timeout_hit}, state}
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
      volume_deployment: %{id: id, device_id: device_id} = volume_deployment,
      retries: retries
    } = state

    Logger.info("""
    Volume deployment #{id} successfully provisioned after #{retries} retries.
    """)

    Phoenix.PubSub.broadcast(
      Edgehog.PubSub,
      "ready:volume_deployments:#{id}",
      {:ready, volume_deployment}
    )

    # Unsubscribe from events, we're terminating
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "volume_deployments:#{id}")
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
  end

  @impl GenServer
  def terminate({:shutdown, reason}, %{volume_deployment: volume_deployment})
      when reason in [:max_retries, :device_offline, :timeout_hit] do
    %{id: id, device_id: device_id} = volume_deployment

    Logger.info("""
    Provisioner for volume deployment #{id} gave up with reason #{inspect(reason)}.
    """)

    # Broadcast failure so that the orchestrator can react
    Phoenix.PubSub.broadcast(
      Edgehog.PubSub,
      "ready:volume_deployments:#{id}",
      {:failure, volume_deployment}
    )

    # Unsubscribe from events, we're terminating
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "volume_deployments:#{id}")
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
  end

  @impl GenServer
  def terminate(reason, state) do
    %{
      volume_deployment: %{id: id, device: %{id: device_id}}
    } = state

    Logger.warning(
      """
      Unexpectedly terminating provisioner for volume deployment #{id} on device #{device_id}.
      Reason: #{inspect(reason)}
      """,
      reason: reason,
      provisioner_state: state
    )
  end
end
