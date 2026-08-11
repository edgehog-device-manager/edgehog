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

defmodule Edgehog.Containers.Provisioner.Core do
  @moduledoc """
  This module provides the default implementation for `Edgehog.Containers.Provisioner.Core.Behaviour`.

  It contains all functions required by the provisioner that handle the
  pure provisioning logic, e.g. sending data to the device.

  To use it, it is sufficient to add a using statement like so:

  ```ex
  defmodule ImageDeploymentProvisioner do
    use Edgehog.Containers.Provisioner, resource: :image

    defmodule Core do
      use Edgehog.Containers.Provisioner.Core, status_verb_key: :pulled
    end
  end
  ```

  The option passed to this module is not required, if used alongside `Edgehog.Containers.Provisioner`:
  so far, the resources have only three possible keys in their
  `Edgehog.Astarte.Device.AvailableResources.ResourceStatus` struct, and to the same
  key correspond the same values. However, it is possible this will change in the
  future (or this module used in different situations) and cause problems, so the
  option exists as an escape hatch.

  **IMPORTANT**: the default implementation relies on attributes set inside of the default
  provisioner implementation to function. If it's not being used, they should be added
  manually if you wish to use this module. Therefore, it is highly encouraged to follow
  the example above for all resource provisioners.
  """

  defmacro __using__(opts) do
    parent_module =
      __CALLER__.module
      |> Module.split()
      |> Enum.drop(-1)
      |> Module.safe_concat()

    status_module = Module.get_attribute(parent_module, :status_module)
    type_atom = Module.get_attribute(parent_module, :type_atom)
    type_string = Module.get_attribute(parent_module, :type_string)
    type_string_camel = Module.get_attribute(parent_module, :type_string_camel)
    available_atom = Module.get_attribute(parent_module, :available_atom)

    status_verb_key =
      case Keyword.fetch(opts, :status_verb_key) do
        # :error or nil
        res when res in [:error, {:ok, nil}] ->
          [status_verb_key] =
            status_module.__struct__()
            |> Map.keys()
            |> Enum.reject(&(&1 in [:id, :__struct__]))

          status_verb_key

        {:ok, status_verb_key} ->
          status_verb_key
      end

    verbs =
      case status_verb_key do
        :pulled -> [:pulled, :unpulled]
        :created -> [:available, :unavailable]
        :present -> [:present, :not_present]
      end

    # credo:disable-for-lines:7 Credo.Check.Warning.UnsafeToAtom
    [positive_status_action, negative_status_action] =
      Enum.map(verbs, fn verb ->
        verb
        |> to_string()
        |> then(&Kernel.<>("mark_as_", &1))
        |> String.to_atom()
      end)

    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote do
      alias Edgehog.Config
      alias Edgehog.Containers.Provisioner.Core
      alias Edgehog.Devices
      alias unquote(status_module), as: ResourceStatus

      require Logger

      @behaviour Core.Behaviour

      defoverridable Core.Behaviour

      @impl Core.Behaviour
      def send(state) do
        %{
          resource_deployment: resource_deployment,
          deployment: deployment,
          tenant: tenant
        } = state

        new_state =
          resource_deployment
          |> send_to_device(tenant: tenant, deployment: deployment)
          |> update_state_on_send(state)

        timeout = timeout(new_state)

        {:noreply, new_state, timeout}
      end

      def maybe_send(state) do
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

      def maybe_early_terminate(%{device_online?: device_online?} = state, next_step) do
        if device_online? do
          next_step
        else
          {:stop, {:shutdown, :device_offline}, state}
        end
      end

      @impl Core.Behaviour
      def send_to_device(resource_deployment, opts) do
        tenant = Keyword.fetch!(opts, :tenant)
        deployment = Keyword.fetch!(opts, :deployment)

        with {:ok, resource_deployment} <-
               Ash.load(resource_deployment, [unquote(type_atom), :device], tenant: tenant),
             {:ok, resource} <- Map.fetch(resource_deployment, unquote(type_atom)),
             {:ok, device} <- Map.fetch(resource_deployment, :device),
             action <-
               String.to_existing_atom("send_create_" <> unquote(type_string) <> "_request"),
             args <- [device, resource, deployment, [tenant: tenant]],
             {:ok, device} <- apply(Devices, action, args) do
          Logger.info("""
          #{unquote(type_string_camel)} #{resource.id} provisioned on device #{device.device_id}. Waiting events
          """)

          :ok
        end
      end

      defp update_state_on_send(:ok, state) do
        Map.put(state, :state, :sent)
      end

      defp update_state_on_send(error, state) do
        %{resource_deployment: %{id: id}} = state

        Logger.warning(
          "Error while sending the deployment #{id}: #{inspect(error)}. The operation will be retried shortly."
        )

        state
      end

      defp increase_retries(state) do
        Map.update!(state, :retries, &Kernel.+(&1, 1))
      end

      @impl Core.Behaviour
      def reconcile(resource_deployment, opts) do
        tenant = Keyword.fetch!(opts, :tenant)

        with {:ok, resource_deployment} <-
               Ash.load(
                 resource_deployment,
                 [{unquote(type_atom), []}, device: [unquote(available_atom)]],
                 tenant: tenant
               ),
             {:ok, resource} <- Map.fetch(resource_deployment, unquote(type_atom)),
             {:ok, device} <- Map.fetch(resource_deployment, :device),
             {:ok, available_resources} <- Map.fetch(device, unquote(available_atom)) do
          available_resources
          |> Enum.find(:not_found, &(&1.id == resource.id))
          |> __maybe_update__(resource_deployment, tenant)
        end
      end

      @impl Core.Behaviour
      def __maybe_update__(%ResourceStatus{} = resource_status, resource_deployment, tenant) do
        action = __update_action__(resource_status)

        # NOTE: this will trigger a publish on the appropriate topic, the
        # provisioner will react to it.
        resource_deployment
        |> Ash.Changeset.for_update(action)
        |> Ash.update(tenant: tenant)
      end

      @impl Core.Behaviour
      def __maybe_update__(other, _resource_deployment, _tenant), do: other

      @impl Core.Behaviour
      def __update_action__(%ResourceStatus{} = status) do
        presence = Map.get(status, unquote(status_verb_key))

        if presence, do: unquote(positive_status_action), else: unquote(negative_status_action)
      end

      @impl Core.Behaviour
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
    end
  end
end
