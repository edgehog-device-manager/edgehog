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
    use Edgehog.Containers.Provisioner, resource: :image
  end
  ```

  Here is how the default implementation works:
  Each and every time an resource should be deployed, it can be done through this
  provisioner. The provisioner sends the appropriate messages to the device and
  emits a `ready:<resource_name>_deployments:id` event whenever resource is present in the
  device.

  The provisioning flow can be described as follows:

  - start_link/1 called, initializing the process and subscribing to the
    events emitted on `<resource_name>_deployments:<id>` (id of the resource deployment)
  - if the resource deployment is already ready, the provisioner terminates normally
    right away, broadcasting readiness
  - otherwise the appropriate messages are sent to the device through the
    `Core` module (see `Core.send/1` docs for more info)

  Nice flow (everything goes ok)
  - Astarte triggers update the resource deployment state, marking it as present or
  not present and emitting an event on the correct topic
  - The server reacts to the event, handles the message and emits an event on
  `ready:<resource_name>_deployments:id` when the resource is ready
  - listening processes can react to this information

  Timeouts (something goes wrong)
  - `Core.send/1` failed, maybe the device is offline, or there was some
    problem with astarte
  - an exponential backoff timeout is started
  - A :timeout hits the server, it retries to send the resource information to the
  device

  TODOs, shortcomigs:
  The logic to handle send succeeding but no message coming back from astarte is
  not there yet
  """

  @module_base Edgehog.Containers

  defmacro __using__(opts) do
    resource_name = Keyword.fetch!(opts, :resource)
    deployment_string = to_string(resource_name)

    {deployment_string, type_string} =
      if String.ends_with?(deployment_string, "_deployment") do
        {deployment_string, String.replace(deployment_string, "_deployment", "")}
      else
        {deployment_string <> "_deployment", deployment_string}
      end

    # all the calls for `String.to_atom/1` are at compile-time, and at a very restricted scope
    # credo:disable-for-lines:30 Credo.Check.Warning.UnsafeToAtom
    type_atom = String.to_existing_atom(type_string)
    deployment_atom = String.to_atom(deployment_string)

    type_string_lower = String.downcase(type_string)
    deployment_string_lower = String.downcase(deployment_string)

    type_string_camel =
      snake_to_camel(type_string)

    module_string_camel = String.replace(type_string_camel, " ", "")
    deployment_module_suffix = String.to_atom(module_string_camel <> ".Deployment")
    deployment_module = Module.safe_concat(@module_base, module_string_camel <> ".Deployment")
    core_module = Module.concat(deployment_module, Provisioner.Core)

    supervisor_module =
      Module.concat(@module_base, module_string_camel <> ".Provisioner.Supervisor")

    available_string = "available_" <> type_string <> "s"
    available_atom = String.to_atom(available_string)

    available_resources_module =
      available_string
      |> snake_to_camel("")
      |> then(&Module.safe_concat(Edgehog.Astarte.Device, &1))

    status_module =
      (module_string_camel <> "Status")
      |> String.to_atom()
      |> then(&Module.safe_concat(available_resources_module, &1))

    # NOTE: All of the variables defined above, especially the ones indicating module
    # atoms, are created on the convention of how we structured the code so far,
    # to reduce boilerplate to a minimum.
    # If in the future we do not follow those conventions anymore, the burden of providing
    # these variables should be on the modules using this macro, and the macro should
    # be updated to simply accept those values.

    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote do
      use GenServer, restart: :transient

      alias Edgehog.Config
      alias unquote(deployment_module)
      alias unquote(core_module)
      alias unquote(Module.safe_concat(@module_base, Provisioner))

      require Logger

      # credo:disable-for-lines:2
      @test Mix.env() == :test
      @sup unquote(supervisor_module)

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

      @behaviour Provisioner.Behaviour

      defoverridable Provisioner.Behaviour

      #### API

      @impl Provisioner.Behaviour
      def provision(resource_deployment, deployment, tenant, opts \\ []) do
        args =
          opts
          |> Keyword.put(unquote(deployment_atom), resource_deployment)
          |> Keyword.put(:deployment, deployment)
          |> Keyword.put(:tenant, tenant)

        child_spec = Supervisor.child_spec({__MODULE__, args}, id: resource_deployment.id)

        with {:error, {:already_started, pid}} <- DynamicSupervisor.start_child(@sup, child_spec) do
          {:ok, pid}
        end
      end

      @impl Provisioner.Behaviour
      def start_link(args) do
        resource_deployment =
          args |> Keyword.fetch!(unquote(deployment_atom)) |> Ash.load!(:device)

        args = Keyword.put(args, :resource_deployment, resource_deployment)

        GenServer.start_link(__MODULE__, args, name: name(resource_deployment))
      end

      @impl Provisioner.Behaviour
      def start(args) do
        resource_deployment =
          args |> Keyword.fetch!(unquote(deployment_atom)) |> Ash.load!(:device)

        args = Keyword.put(args, :resource_deployment, resource_deployment)

        GenServer.start(__MODULE__, args, name: name(resource_deployment))
      end

      @impl Provisioner.Behaviour
      def name(%Deployment{id: id}) do
        {:via, Registry,
         {unquote(Module.concat(deployment_module_suffix, Provisioner.Registry)), id}}
      end

      #### Callbacks

      @impl GenServer
      def init(args) do
        resource_deployment = Keyword.fetch!(args, :resource_deployment)
        deployment = Keyword.fetch!(args, :deployment)
        tenant = Keyword.fetch!(args, :tenant)

        mode = Keyword.get(args, :mode, :auto)

        %{id: id, device: %{id: device_id, online: device_online?}} =
          resource_deployment

        state = %{
          resource_deployment: resource_deployment,
          deployment: deployment,
          device_online?: device_online?,
          tenant: tenant,
          state: :init,
          mode: mode,
          retries: 0
        }

        Logger.info("Subscribing to events on #{unquote(type_string_lower)} deployment #{id}")
        Phoenix.PubSub.subscribe(Edgehog.PubSub, "#{unquote(deployment_string_lower)}s:#{id}")

        Logger.info(
          "Subscribing to status events of device #{device_id} for #{unquote(type_string_lower)} deployment #{id}"
        )

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
        next_step = {:noreply, state, {:continue, :check_deployment_state}}
        Core.maybe_early_terminate(state, next_step)
      end

      @impl GenServer
      def handle_continue(:maybe_start, %{mode: :manual} = state) do
        next_step = {:noreply, state}
        Core.maybe_early_terminate(state, next_step)
      end

      @impl GenServer
      def handle_continue(
            :check_deployment_state,
            %{resource_deployment: resource_deployment} = state
          ) do
        resource_deployment =
          Ash.load!(resource_deployment, :is_ready, tenant: resource_deployment.tenant_id)

        if resource_deployment.is_ready do
          new_state = Map.put(state, :resource_deployment, resource_deployment)
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
        %{resource_deployment: resource_deployment, tenant: tenant} = state

        rec = Core.reconcile(resource_deployment, tenant: tenant)

        case rec do
          :not_found ->
            Core.maybe_send(state)

          {:ok, resource_deployment} ->
            # Reconciliation updated the resource deployment, just update the state as a
            # new message will come in the queue
            new_state = Map.put(state, :resource_deployment, resource_deployment)

            # This just in case the message is not actually there, but I'd consider it a bug
            timeout = Core.timeout(state)

            {:noreply, new_state, timeout}
        end
      end

      # The resource deployment provisioning deadline was hit, give up and broadcast a
      # failure so that the orchestrator can react
      @impl GenServer
      def handle_info(:give_up, state) do
        Logger.warning("""
        #{unquote(type_string_camel)} deployment #{state.resource_deployment.id} provisioning timed out. Giving up.
        """)

        {:stop, {:shutdown, :timeout_hit}, state}
      end

      # We get the resource deployment from the broadcast, which is in the :payload ->
      # :data section. This resource deployment is more recent, as it comes from an
      # update in the database.
      @impl GenServer
      def handle_info(
            %Phoenix.Socket.Broadcast{payload: %{data: %Deployment{} = resource_deployment}},
            state
          ) do
        # We can publish on readiness topic.
        id = resource_deployment.id

        Phoenix.PubSub.broadcast(
          Edgehog.PubSub,
          "ready:#{unquote(deployment_string_lower)}s:#{id}",
          {:ready, resource_deployment}
        )

        new_state = Map.put(state, :resource_deployment, resource_deployment)

        # Somewhere the resource has been marked in some state (i.e: pulled/unpulled for images). For
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
          resource_deployment: %{id: id, device_id: device_id} = resource_deployment,
          retries: retries
        } = state

        Logger.info("""
        #{unquote(type_string_camel)} deployment #{id} successfully provisioned after #{retries} retries.
        """)

        # Broadcast readiness so that the orchestrator can proceed
        Phoenix.PubSub.broadcast(
          Edgehog.PubSub,
          "ready:#{unquote(deployment_string_lower)}s:#{id}",
          {:ready, resource_deployment}
        )

        # Unsubscribe from events, we're terminating
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "#{unquote(deployment_string_lower)}s:#{id}")
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
      end

      @impl GenServer
      def terminate({:shutdown, reason}, %{resource_deployment: resource_deployment})
          when reason in [:max_retries, :device_offline, :timeout_hit] do
        %{id: id, device_id: device_id} = resource_deployment

        Logger.info("""
        Provisioner for #{unquote(type_string_lower)} deployment #{id} gave up with reason #{inspect(reason)}.
        """)

        # Broadcast readiness so that the orchestrator can proceed
        Phoenix.PubSub.broadcast(
          Edgehog.PubSub,
          "ready:#{unquote(deployment_string_lower)}s:#{id}",
          {:failure, resource_deployment}
        )

        # Unsubscribe from events, we're terminating
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "#{unquote(deployment_string_lower)}s:#{id}")
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
      end

      @impl GenServer
      def terminate(reason, state) do
        %{
          resource_deployment: %{id: id, device: %{id: device_id}}
        } = state

        Logger.warning(
          """
          Unexpectedly terminating provisioner for #{unquote(type_string_lower)} deployment #{id} on device #{device_id}.
          Reason: #{inspect(reason)}
          """,
          reason: reason,
          provisioner_state: state
        )
      end

      @status_module unquote(status_module)
      @type_atom unquote(type_atom)
      @type_string unquote(type_string)
      @type_string_camel unquote(type_string_camel)
      @available_atom unquote(available_atom)
    end
  end

  defp snake_to_camel(str, camel_delimiter \\ " ") do
    str |> String.split("_") |> Enum.map_join(camel_delimiter, &String.capitalize/1)
  end
end
