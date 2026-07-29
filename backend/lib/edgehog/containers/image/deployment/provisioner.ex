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

defmodule Edgehog.Containers.Image.Deployment.Provisioner do
  @moduledoc """
  A image deployment provisioner.

  Each and every time an image should be deployed, it can be done through this
  provisioner. The provisioner sends the appropriate messages to the device and
  emits a `ready:image_deployments:id` event whenever image is present in the
  device.

  The provisioning flow can be described as follows:

  - start_link/1 called, init the process
  - The server subscribes to events on 'image_deployments:id' (id of the image
    deployment)
  - Core.send/2 is called, sending the appropriate messages to the device (see
    Core.send/1 docs for more info)

  Nice flow (everything goes ok)
  - Astarte triggers update the image deployment state, marking it as present or
    not present and emitting an event on the correct topic
  - The server reacts to the event, handles the message and emits an event on
    'ready:image_deployment:id' when the resource is ready
  - listening processes can react to this information

  Timeouts (something goes wrong)
  - Core.send/2 failed, maybe the device is offline, or there was some problem
    with astarte
  - an exponential backoff timeout is started
  - A :timeout hits the server, it retries to send the image information to the
    device

  TODOs, shortcomigs:
  The logic to handle send succeeding but no message coming back from astarte is
  not there yet
  """

  use GenServer, restart: :transient

  alias Edgehog.Config
  alias Edgehog.Containers.Image.Deployment
  alias Edgehog.Containers.Image.Deployment.Provisioner.Core

  require Logger

  @test Mix.env() == :test

  #### API

  @doc """
  Starts the provisioner of an image deployment.

  Equivalent to starting the provisioner through `start_link/1` with opts
  ```
  [
    image_deployment: image_deployment,
    deployment: deployment,
    tenant: tenant
  ]
  ```

  See `start_link/1` docs for more information.
  """
  def provision(image_deployment, deployment, tenant, opts \\ []) do
    opts
    |> Keyword.put(:image_deployment, image_deployment)
    |> Keyword.put(:deployment, deployment)
    |> Keyword.put(:tenant, tenant)
    |> start_link()
  end

  @doc """
  Starts a provisioner for an image deployment.

  A provision for this resource follows the following flow:

  - checks that the resource is not ready already (i.e., the device never received it).
  - tries to send the deployment information to astarte (calling `&Devices.send_image_deployment/2`)
  - if an unrecoverable error occurs, broadcasts a failure on the `topic/1` topic.
  - if successful, waits for events on the image deployment itself.

  - if a trigger reaches edgehog, it changes a property in the image deployment resource, emitting an event for the provsioner.
  - the provisioner understands that the image is ready, it then exits successfully.

  - if the reconciler has no messages incoming after a timer defined through the `timeout/1` function:
    + checks for readiness of the resource, maybe we just missed the message
    + queries astarte, maybe the trigger was missing
    + retries to send the message to the device.
    + loops with a new timeout set by the `timeout/1` function.
  """
  def start_link(args) do
    image_deployment = args |> Keyword.fetch!(:image_deployment) |> Ash.load!(:device)
    args = Keyword.put(args, :image_deployment, image_deployment)

    GenServer.start_link(__MODULE__, args, name: name(image_deployment))
  end

  @doc """
  Starts a provisioner for an image deployment, without linking it to the
  current process.

  See `start_link/1` docs for more information
  """
  def start(args) do
    image_deployment = args |> Keyword.fetch!(:image_deployment) |> Ash.load!(:device)
    args = Keyword.put(args, :image_deployment, image_deployment)

    GenServer.start(__MODULE__, args, name: name(image_deployment))
  end

  def name(%Deployment{id: id}) do
    {:via, Registry, {Image.Deployment.Provisioner.Registry, id}}
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
    image_deployment = Keyword.fetch!(args, :image_deployment)
    deployment = Keyword.fetch!(args, :deployment)
    tenant = Keyword.fetch!(args, :tenant)

    mode = Keyword.get(args, :mode, :auto)

    %{id: id, device: %{id: device_id, online: device_online?}} =
      image_deployment

    state = %{
      image_deployment: image_deployment,
      deployment: deployment,
      device_online?: device_online?,
      tenant: tenant,
      state: :init,
      mode: mode,
      retries: 0
    }

    Logger.info("Subscribing to events on image deployment #{id}")
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "image_deployments:#{id}")

    Logger.info("Subscribing to status events of device #{device_id} for image deployment #{id}")
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
  def handle_continue(:check_deployment_state, %{image_deployment: image_deployment} = state) do
    image_deployment = Ash.load!(image_deployment, :is_ready, tenant: image_deployment.tenant_id)

    if image_deployment.is_ready do
      new_state = Map.put(state, :image_deployment, image_deployment)
      {:stop, :normal, new_state}
    else
      {:noreply, state, {:continue, :send}}
    end
  end

  @impl GenServer
  def handle_continue(:send, state), do: send(state)

  # We were not able to send the message to the device. retry
  @impl GenServer
  def handle_info(:timeout, %{state: :init} = state), do: send(state)

  # We sent the message to the device, but no trigger came back.
  # 1. Reconcile with astarte
  # 2. if still nothing has come back, retry to send
  @impl GenServer
  def handle_info(:timeout, %{state: :sent} = state) do
    %{image_deployment: image_deployment, tenant: tenant} = state

    rec = Core.reconcile(image_deployment, tenant: tenant)

    case rec do
      :not_found ->
        maybe_send(state)

      {:ok, image_deployment} ->
        # Reconciliation updated the image deployment, just update the state as a
        # new message will come in the queue
        new_state = Map.put(state, :image_deployment, image_deployment)

        # This just in case the message is not actually there, but I'd consider it a bug
        timeout = Core.timeout(state)

        {:noreply, new_state, timeout}
    end
  end

  # We get the image deployment from the broadcast, which is in the :payload ->
  # :data section. This image deployment is more recent, as it comes from an
  # update in the database.
  @impl GenServer
  def handle_info(
        %Phoenix.Socket.Broadcast{payload: %{data: %Deployment{} = image_deployment}},
        state
      ) do
    # We can publish on readiness topic.
    id = image_deployment.id

    Phoenix.PubSub.broadcast(
      Edgehog.PubSub,
      "ready:image_deployments:#{id}",
      {:ready, image_deployment}
    )

    new_state = Map.put(state, :image_deployment, image_deployment)

    # Somewhere the image has been marked in some state (pulled/unpulled). For
    # now we can just shutdown gracefully
    {:stop, :normal, new_state}
  end

  @impl GenServer
  def handle_info(%Phoenix.Socket.Broadcast{topic: "devices:offline:" <> _id}, old_state) do
    new_state = Map.put(old_state, :device_online?, false)

    {:stop, {:shutdown, :device_offline}, new_state}
  end

  # NOTICE: we crash on messages that do not come from the notification system for the correct topics

  @impl GenServer
  def terminate(:normal, state) do
    %{
      image_deployment: %{id: id, device_id: device_id},
      retries: retries
    } = state

    Logger.info("""
    Image deployment #{id} successfully provisioned after #{retries} retries.
    """)

    # Unsubscribe from events, we're terminating
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "image_deployments:#{id}")
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
  end

  @impl GenServer
  def terminate({:shutdown, :device_offline}, state) do
    %{
      image_deployment: %{id: id, device_id: device_id}
    } = state

    Logger.info("""
    Device #{device_id} went offline. Provisioner for image deployment #{id} terminating.
    """)

    # Unsubscribe from events, we're terminating
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "image_deployments:#{id}")
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
  end

  @impl GenServer
  def terminate(reason, state) do
    %{
      image_deployment: %{id: id, device: %{id: device_id}}
    } = state

    Logger.warning(
      """
      Unexpectedly terminating provisioner for image deployment #{id} on device #{device_id}.
      Reason: #{inspect(reason)}
      """,
      reason: reason,
      provisioner_state: state
    )
  end

  #### Helper functions

  # Send the image if the number of retries does not exceed the max number of
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

  # Sends the image deployment, without asking any questions. To check for
  # retries, use `maybe_send`.
  defp send(state) do
    %{
      image_deployment: image_deployment,
      deployment: deployment,
      tenant: tenant
    } = state

    new_state =
      image_deployment
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
    %{image_deployment: %{id: id}} = state

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
end
