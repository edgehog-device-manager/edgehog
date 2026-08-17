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

defmodule Edgehog.Containers.Provisioner do
  @moduledoc """
  This module provides the default implementation for `Edgehog.Containers.Provisioner.Behaviour`.
  It is sufficient to add a using statement like so:

  ```ex
  defmodule ResourceDeployment.Provisioner do
    @sup Edgehog.Containers.Resource.Provisioner.Supervisor

    use Edgehog.Containers.Provisioner, resource: Edgehog.Containers.Resource.Deployment, core: Core
  end
  ```

  where `resource` is the module of the resource to provision. The provisioner
  is a `GenServer` that takes a resource (not just deployments) and orchestrates
  the whole provisioning with the device: sending requests, managing timeouts,
  retries and errors.

  The resource specific logic is delegated to the `Core` module nested inside
  the provisioner (see `Edgehog.Containers.Provisioner.Core.Behaviour`): pure
  functions that can be tested in isolation (e.g. `ready?/1`, `topic/1`) and
  functions that provide the side effects of the provisioning (e.g.
  `send_to_device/2`, `reconcile/2`).

  The provisioning flow can be described as follows:

  - `start_link/1` called, initializing the process and subscribing to the
    events emitted on `Core.subscribe_topic/1`
  - if the resource is already ready, the provisioner terminates normally
    right away, broadcasting readiness
  - otherwise the appropriate messages are sent to the device through the
    `Core` module (see `Core.send_to_device/2` docs for more info)

  Nice flow (everything goes ok)
  - Astarte triggers update the resource state, marking it as present or
  not present and emitting an event on the correct topic
  - The server reacts to the event, handles the message and emits an event on
  `Core.topic/1` when the resource is ready
  - listening processes can react to this information

  Timeouts (something goes wrong)
  - `Core.send_to_device/2` failed, maybe the device is offline, or there was
    some problem with astarte
  - an exponential backoff timeout is started
  - A :timeout hits the server, it retries to send the resource information to
    the device
  """

  defmacro __using__(opts) do
    resource_module = Keyword.fetch!(opts, :resource)

    core_module = Keyword.fetch!(opts, :core)

    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote do
      use GenServer, restart: :transient

      alias Edgehog.Config
      alias Edgehog.Containers.Provisioner
      alias unquote(core_module), as: Core
      alias unquote(resource_module), as: Resource

      require Logger

      @before_compile unquote(__MODULE__)

      # credo:disable-for-lines:2
      @test Mix.env() == :test

      # Test additional API
      # In test environment, allow to run the process with a message, so that the
      # test process can attach and monitor it
      if @test do
        def run(provisioner) do
          GenServer.cast(provisioner, :run)
        end

        @impl GenServer
        def handle_cast(:run, state) do
          {:noreply, state, {:continue, :check_state}}
        end
      end

      @behaviour Provisioner.Behaviour

      #### API

      @impl Provisioner.Behaviour
      def start_link(args) do
        resource = args |> Keyword.fetch!(:resource) |> Ash.load!(:device)

        args = Keyword.put(args, :resource, resource)

        GenServer.start_link(__MODULE__, args, name: Core.name(resource))
      end

      @impl Provisioner.Behaviour
      def start(args) do
        resource = args |> Keyword.fetch!(:resource) |> Ash.load!(:device)

        args = Keyword.put(args, :resource, resource)

        GenServer.start(__MODULE__, args, name: Core.name(resource))
      end

      @impl Provisioner.Behaviour
      def timeout(state) do
        %{
          state: d_state,
          retries: retries
        } = state

        pad = pad(d_state)

        exp = :math.pow(2, retries)

        rand = Enum.random(0..1000)

        max_timeout = Config.message_max_timeout!()

        pad
        |> Kernel.+(exp)
        |> Kernel.+(rand)
        |> min(max_timeout)
        |> round()
      end

      defp pad(:sent), do: Config.message_min_timeout!()
      defp pad(:init), do: 0

      #### Callbacks

      @impl GenServer
      def init(args) do
        resource = Keyword.fetch!(args, :resource)
        tenant = Keyword.fetch!(args, :tenant)

        mode = Keyword.get(args, :mode, :auto)

        # The remaining options are resource specific context that the Core
        # might need (e.g. the application deployment a resource belongs to).
        context = Keyword.drop(args, [:resource, :tenant, :mode])

        %{id: id, device: %{id: device_id, online: device_online?}} = resource

        state = %{
          resource: resource,
          tenant: tenant,
          context: context,
          device_online?: device_online?,
          state: :init,
          mode: mode,
          retries: 0
        }

        topic = Core.subscribe_topic(resource)

        Logger.info("Subscribing to events on #{topic}")
        Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

        Logger.info("Subscribing to status events of device #{device_id}")

        Phoenix.PubSub.subscribe(Edgehog.PubSub, "devices:offline:#{device_id}")

        Logger.debug(
          "Device #{device_id} is currently #{if device_online?, do: "online", else: "offline"}"
        )

        # If the provisioning does not complete within the deadline, the
        # provisioner gives up and broadcasts a failure that the orchestrator reacts
        # to
        deadline = Config.deployment_provisioning_timeout!()
        Process.send_after(self(), :give_up, deadline)

        {:ok, state, {:continue, :maybe_start}}
      end

      @impl GenServer
      def handle_continue(:maybe_start, %{mode: :auto} = state) do
        next_step = {:noreply, state, {:continue, :check_state}}
        maybe_early_terminate(state, next_step)
      end

      @impl GenServer
      def handle_continue(:maybe_start, %{mode: :manual} = state) do
        next_step = {:noreply, state}
        maybe_early_terminate(state, next_step)
      end

      @impl GenServer
      def handle_continue(:check_state, %{resource: resource} = state) do
        if Core.ready?(resource) do
          {:stop, :normal, state}
        else
          {:noreply, state, {:continue, :send}}
        end
      end

      @impl GenServer
      def handle_continue(:send, state), do: maybe_send(state)

      # We were not able to send the message to the device. retry
      @impl GenServer
      def handle_info(:timeout, %{state: :init} = state), do: maybe_send(state)

      # We sent the message to the device, but no trigger came back.
      # 1. Reconcile with astarte
      # 2. if still nothing has come back, retry to send
      @impl GenServer
      def handle_info(:timeout, %{state: :sent} = state) do
        %{resource: resource, tenant: tenant} = state

        case Core.reconcile(resource, tenant: tenant) do
          :not_found ->
            maybe_send(state)

          {:ok, resource} ->
            # Reconciliation updated the resource, just update the state as a
            # new message will come in the queue
            new_state = Map.put(state, :resource, resource)

            # This just in case the message is not actually there, but I'd consider it a bug
            timeout = timeout(new_state)

            {:noreply, new_state, timeout}
        end
      end

      # The provisioning deadline was hit, give up and broadcast a
      # failure so that the orchestrator can react
      @impl GenServer
      def handle_info(:give_up, state) do
        Logger.warning("""
        Resource #{state.resource.id} provisioning timed out. Giving up.
        """)

        {:stop, {:shutdown, :timeout_hit}, state}
      end

      # We get the resource from the broadcast, which is in the :payload ->
      # :data section. This resource is more recent, as it comes from an
      # update in the database.
      @impl GenServer
      def handle_info(
            %Phoenix.Socket.Broadcast{payload: %{data: %Resource{} = resource}},
            state
          ) do
        new_state = Map.put(state, :resource, resource)

        # The resource has been updated, check if it's ready and, in that case,
        # terminate gracefully. Otherwise keep waiting with a new timeout.
        if Core.ready?(resource) do
          {:stop, :normal, new_state}
        else
          {:noreply, new_state, timeout(new_state)}
        end
      end

      @impl GenServer
      def handle_info(%Phoenix.Socket.Broadcast{topic: "devices:offline:" <> _id}, old_state) do
        new_state = Map.put(old_state, :device_online?, false)

        {:stop, {:shutdown, :device_offline}, new_state}
      end

      # NOTICE: we crash on messages that do not come from the notification system for the correct topics

      @impl GenServer
      def terminate(:normal, state) do
        %{resource: %{id: id, device_id: device_id} = resource} = state

        Logger.info("""
        Resource #{id} successfully provisioned after #{state.retries} retries.
        """)

        # Broadcast readiness so that the orchestrator can proceed
        Phoenix.PubSub.broadcast(Edgehog.PubSub, Core.topic(resource), {:ready, resource})

        # Unsubscribe from events, we're terminating
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, Core.subscribe_topic(resource))
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
      end

      @impl GenServer
      def terminate({:shutdown, reason}, %{resource: resource})
          when reason in [:max_retries, :device_offline, :timeout_hit] do
        %{id: id, device_id: device_id} = resource

        Logger.info("""
        Provisioner for resource #{id} gave up with reason #{inspect(reason)}.
        """)

        # Broadcast failure so that the orchestrator can react
        Phoenix.PubSub.broadcast(Edgehog.PubSub, Core.topic(resource), {:failure, resource})

        # Unsubscribe from events, we're terminating
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, Core.subscribe_topic(resource))
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
      end

      @impl GenServer
      def terminate(reason, state) do
        %{resource: %{id: id, device: %{id: device_id}}} = state

        Logger.warning(
          """
          Unexpectedly terminating provisioner for resource #{id} on device #{device_id}.
          Reason: #{inspect(reason)}
          """,
          reason: reason,
          provisioner_state: state
        )
      end

      defp maybe_early_terminate(%{device_online?: device_online?} = state, next_step) do
        if device_online? do
          next_step
        else
          {:stop, {:shutdown, :device_offline}, state}
        end
      end

      defp maybe_send(state) do
        retries = Map.fetch!(state, :retries)
        max_retries = Config.max_retries!()

        if retries < max_retries do
          state
          |> increase_retries()
          |> send_resource()
        else
          {:stop, {:shutdown, :max_retries}, state}
        end
      end

      defp send_resource(state) do
        %{resource: resource, tenant: tenant, context: context} = state

        opts = [tenant: tenant] ++ context

        new_state =
          case Core.send_to_device(resource, opts) do
            :ok ->
              Map.put(state, :state, :sent)

            error ->
              Logger.warning(
                "Error while sending the resource #{resource.id}: #{inspect(error)}. The operation will be retried shortly."
              )

              state
          end

        timeout = timeout(new_state)

        {:noreply, new_state, timeout}
      end

      defp increase_retries(state) do
        Map.update!(state, :retries, &Kernel.+(&1, 1))
      end

      defoverridable Provisioner.Behaviour
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    case Module.defines?(env.module, {:provision, 3}) do
      false ->
        sup = Module.get_attribute(env.module, :sup)

        if is_nil(sup) do
          raise "the `@sup` module attribute must be set before `use Edgehog.Containers.Provisioner`, " <>
                  "specifying the supervisor under which the provisioner processes are started. " <>
                  "Alternatively, override the `provision/3` callback to start the process as needed."
        end

        quote do
          @impl Edgehog.Containers.Provisioner.Behaviour
          def provision(resource, tenant, opts \\ []) do
            args =
              opts
              |> Keyword.put(:resource, resource)
              |> Keyword.put(:tenant, tenant)

            child_spec = Supervisor.child_spec({__MODULE__, args}, id: resource.id)

            with {:error, {:already_started, pid}} <-
                   DynamicSupervisor.start_child(unquote(sup), child_spec) do
              {:ok, pid}
            end
          end
        end

      true ->
        quote(do: :ok)
    end
  end
end
