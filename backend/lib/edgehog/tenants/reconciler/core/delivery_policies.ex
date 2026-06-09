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

defmodule Edgehog.Tenants.Reconciler.Core.DeliveryPolicies do
  @moduledoc """
  Edgehog tenant reconciler responsible for delivery policies.

  This module has a main entrypoint: `reconcile/1`

  `reconcile/1` expects a `Edgehog.Tenants.Reconciler.Core` context with
  - a realm management client
  - the astarte version

  and installs delivery policies accordingly.

  It adds a key to the context stating whether delivery polices are compatible or not:

  ```elixir
  delivery_policies_compatible: true | false
  ```

  If errors happen while installing the delivery policies, corresponding entries are added to the context.

  ```elixir
  errors: [delivery_policies: [error1, error2, ...]]
  ```
  """

  alias Edgehog.Astarte.DeliveryPolicies
  alias Edgehog.Astarte.Trigger
  alias Edgehog.Tenants.Reconciler.AstarteResources
  alias Edgehog.Tenants.Reconciler.Context
  alias Edgehog.Tenants.Reconciler.Core

  require Logger

  @delivery_policies AstarteResources.load_delivery_policies()
  @minimum_astarte_version_with_policies_support "1.1.1"
  @error_section :delivery_policies

  @doc """
  Given a context, installs the necessary trigger delivery policies.

  - first it checks against the recorded astarte version.
  - if the minimum required for trigger delivery policies installation is met, then proceeds to install the necessary policies.
  - if the minimum required version is not met, then no delivery policies are installed.

  A new key is added to the context: `delivery_policies_compatible`, stating
  whether astarte is compatible with trigger delivery policies.

  Notice: this function might have the side effect of uninstalling all triggers that previously referenced a delivery policy.

  Since updating a delivery policy is actually not possible, what we have to do is

  - uninstall all the triggers that referenced the old policy
  - uninstall the policy
  - install the new policy

  This leaves the triggers uninstalled, as at this stage we don't have a notion
  of what triggers were present in astarte.
  """
  def reconcile(%{astarte_version: version} = context) do
    context
    |> Context.add_context(delivery_policies_compatible: compatible?(version))
    |> reconcile_delivery_policies()
  end

  defp compatible?(version) do
    Version.compare(@minimum_astarte_version_with_policies_support, version) != :gt
  end

  @doc """
  Lists all delivery policies under `priv/astarte_resources/delivery_policies`

  All returned delivery policies are `EEx` evaluated and `Jason` decoded,
  effectively returning a map of all properties of the delivery policy.
  """
  def list_delivery_policies do
    Enum.map(@delivery_policies, fn policy ->
      policy
      |> EEx.eval_string()
      |> Jason.decode!()
    end)
  end

  defp reconcile_delivery_policies(%{delivery_policies_compatible: false} = context),
    do: context

  defp reconcile_delivery_policies(%{delivery_policies_compatible: true} = context) do
    %{tenant: %{slug: slug}} = context
    Logger.info("Reconciling trigger delivery policies for tenant #{slug}.")

    reduction = Enum.reduce_while(list_delivery_policies(), context, &reduce_context/2)

    with {:error, error} <- reduction do
      Context.add_error(context, @error_section, error)
    end
  end

  defp reduce_context(policy, context) do
    case reconcile_delivery_policy(context, policy) do
      {:error, error} -> {:halt, {:error, error}}
      context -> {:cont, context}
    end
  end

  def reconcile_delivery_policy(%{rm_client: rm_client} = context, policy) do
    %{"name" => name} = policy

    call = DeliveryPolicies.fetch_by_name(rm_client, name)

    update_or_install(context, call, policy)
  end

  # ===================== Update or install

  defp update_or_install(context, {:ok, existing}, policy) do
    if matches?(existing, policy),
      do: context,
      else: update(context, policy)
  end

  defp update_or_install(context, {:error, :not_found}, policy) do
    install(context, policy)
  end

  defp update_or_install(context, error, policy) do
    %{tenant: %{slug: slug}} = context
    %{"name" => name} = policy

    log_error = """
    Error while reconciling trigger delivery policy:

    - policy: #{name}
    - tenant: #{slug}

    #{inspect(error)}

    Is the connection with astarte ok?
    """

    Logger.error(log_error)

    error
  end

  # ===================== Update

  defp update(context, policy) do
    %{"name" => name} = policy
    %{rm_client: rm_client} = context

    with {:ok, triggers} <- list_triggers_that_reference_policy(rm_client, policy),
         false <- context |> Core.Triggers.delete(triggers) |> Context.errors?(:triggers),
         :ok <- DeliveryPolicies.delete(rm_client, name) do
      install(context, policy)
    else
      {:error, error} ->
        log_error = """
        Error while updating policy #{name}:
        #{inspect(error)}

        Common causes are
        - It was not possible to remove the triggers that referenced the policy
        - It was not possible to remove the old policy
        - Handlers are incorrectly configured or not correct w.r.t. the Astarte version

        NOTICE: This procedure might have left side effect in your astarte instance, part of the process of updating delivery policies
                involves removing triggers and the delivery policy, check your triggers!
        """

        Logger.error(log_error)
        Context.add_error(context, @error_section, error)
    end
  end

  defp list_triggers_that_reference_policy(rm_client, policy) do
    %{"name" => name} = policy

    with {:ok, %{"data" => trigger_names}} <- Trigger.list(rm_client) do
      triggers_that_reference_policy =
        trigger_names
        |> Enum.map(fn trigger_name ->
          {:ok, trigger} = Trigger.fetch_by_name(rm_client, trigger_name)
          trigger
        end)
        |> Enum.filter(&(&1["policy"] == name))

      {:ok, triggers_that_reference_policy}
    end
  end

  # ===================== Install

  defp install(context, policy) do
    %{rm_client: rm_client} = context
    %{"name" => name} = policy

    case DeliveryPolicies.create(rm_client, policy) do
      :ok ->
        context

      {:error, error} ->
        log_error = """
        Error while installing policy #{name}:
        #{inspect(error)}

        Common causes are
        - a policy with the same name already exists
        - handlers are incorrectly configured or not correct w.r.t. the astarte version
        """

        Logger.error(log_error)
        Context.add_error(context, @error_section, error)
    end
  end

  defp matches?(existing, policy) do
    contains?(normalize(existing), normalize(policy))
  end

  defp normalize(policy) do
    policy
    |> update_in(["retry_times"], &(&1 || 0))
    |> update_in(["prefetch_count"], &(&1 || 0))
    |> sort_error_handlers()
  end

  defp sort_error_handlers(policy) do
    error_handlers =
      policy
      |> Map.get("error_handlers", [])
      |> Enum.sort_by(&Map.get(&1, "on"))

    Map.put(policy, "error_handlers", error_handlers)
  end

  defp contains?(%{} = supermap, %{} = submap) do
    Enum.all?(submap, fn {key, sub_val} ->
      case Map.fetch(supermap, key) do
        {:ok, super_val} -> contains?(super_val, sub_val)
        :error -> false
      end
    end)
  end

  defp contains?(super_val, sub_val), do: super_val == sub_val
end
