#
# This file is part of Edgehog.
#
# Copyright 2023 - 2025 SECO Mind Srl
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

defmodule Edgehog.Tenants.Reconciler.Core do
  @moduledoc false
  alias Astarte.Client
  alias Astarte.Client.RealmManagement
  alias Edgehog.Astarte.DeliveryPolicies
  alias Edgehog.Astarte.Interface
  alias Edgehog.Astarte.Trigger
  alias Edgehog.Tenants.Reconciler.AstarteResources

  require Logger

  @minimum_astarte_version_with_registration_triggers_support "1.3.0"

  @interfaces AstarteResources.load_interfaces()
  @delivery_policies AstarteResources.load_delivery_policies()
  @trigger_templates AstarteResources.load_trigger_templates()

  def list_required_interfaces do
    @interfaces
  end

  def list_required_delivery_policies do
    Enum.map(@delivery_policies, fn policy ->
      policy
      |> EEx.eval_string()
      |> Jason.decode!()
    end)
  end

  def list_required_triggers(trigger_url, can_use_trigger_delivery_policy \\ false) do
    Enum.map(@trigger_templates, fn template ->
      template
      |> EEx.eval_string(
        assigns: [
          trigger_url: trigger_url,
          can_use_trigger_delivery_policy: can_use_trigger_delivery_policy
        ]
      )
      |> Jason.decode!()
    end)
  end

  def reconcile_interface!(%Client.RealmManagement{} = client, required_interface) do
    %{
      "interface_name" => interface_name,
      "version_major" => required_major,
      "version_minor" => required_minor
    } = required_interface

    case Interface.fetch_by_name_and_major(client, interface_name, required_major) do
      {:ok, %{"version_major" => ^required_major, "version_minor" => existing_minor}} ->
        if required_minor > existing_minor do
          update_interface!(client, interface_name, required_major, required_interface)
        else
          :ok
        end

      # This intentionally doesn't match on different errors. We want to crash
      # on them, since the tenant reconciliation is isolated in a Task.
      # TODO: raise nicer exceptions instead of crashing with CaseClauseError
      {:error, :not_found} ->
        install_interface!(client, required_interface)
    end
  end

  def reconcile_delivery_policy!(%Client.RealmManagement{} = client, required_policy) do
    %{
      "name" => policy_name
    } = required_policy

    case DeliveryPolicies.fetch_by_name(client, policy_name) do
      {:ok, existing_policy} ->
        if delivery_policy_matches?(existing_policy, required_policy) do
          :ok
        else
          update_delivery_policy!(client, policy_name, required_policy)
        end

      # This intentionally doesn't match on different errors since we want to crash
      # on them, since the tenant reconciliation is isolated in a Task
      # TODO: raise nicer exceptions instead of crashing with CaseClauseError
      {:error, :not_found} ->
        install_delivery_policy!(client, required_policy)
    end
  end

  def reconcile_trigger!(%Client.RealmManagement{} = client, required_trigger, astarte_version, tenant) do
    if trigger_compatible?(astarte_version, required_trigger) do
      do_reconcile_trigger(client, required_trigger)
    else
      Logger.warning(
        "Skipping reconciliation for tenant #{tenant.tenant_id} and trigger #{required_trigger["name"]}, astarte minimum requirement not met."
      )

      :ok
    end
  end

  defp trigger_compatible?(astarte_version, required_trigger) do
    check_on_device_registered_and_deletion(astarte_version, required_trigger)
  end

  defp check_on_device_registered_and_deletion(astarte_version, %{"simple_triggers" => simple_triggers}) do
    features_1_3? =
      Enum.any?(simple_triggers, fn simple_trigger ->
        on = simple_trigger["on"]

        on == "device_registered" || on == "device_deletion_started" ||
          on == "device_deletion_finished"
      end)

    # If the trigger is using astarte 1.3 features we should check the
    # compatibility. Otherwise this step can be skipped, device registration and
    # compatibility is `true`
    if features_1_3?,
      do:
        min_version_matches(
          astarte_version,
          @minimum_astarte_version_with_registration_triggers_support
        ),
      else: true
  end

  defp do_reconcile_trigger(client, required_trigger) do
    %{
      "name" => trigger_name
    } = required_trigger

    case Trigger.fetch_by_name(client, trigger_name) do
      {:ok, existing_trigger} ->
        if trigger_matches?(existing_trigger, required_trigger) do
          :ok
        else
          update_trigger!(client, trigger_name, required_trigger)
        end

      # This intentionally doesn't match on different errors since we want to crash
      # on them, since the tenant reconciliation is isolated in a Task
      # TODO: raise nicer exceptions instead of crashing with CaseClauseError
      {:error, :not_found} ->
        install_trigger!(client, required_trigger)
    end
  end

  def min_version_matches(astarte_version, min_version) do
    Version.compare(min_version, astarte_version) != :gt
  end

  defp update_interface!(rm_client, name, major, interface_json) do
    # TODO: crash with a nicer exception instead of MatchError
    :ok = Interface.update(rm_client, name, major, interface_json)

    :ok
  end

  defp install_interface!(rm_client, interface_json) do
    # TODO: crash with a nicer exception instead of MatchError
    :ok = Interface.create(rm_client, interface_json)

    :ok
  end

  defp update_delivery_policy!(rm_client, policy_name, policy_json) do
    # Policies don't have a way to update them, so we delete it and install it again

    # TODO: crash with a nicer exception instead of MatchError
    with {:ok, triggers} <- list_triggers_that_reference_policy(rm_client, policy_name),
         :ok <- delete_triggers(rm_client, triggers),
         :ok <- DeliveryPolicies.delete(rm_client, policy_name) do
      install_delivery_policy!(rm_client, policy_json)
    end

    :ok
  end

  defp install_delivery_policy!(rm_client, policy_json) do
    # TODO: crash with a nicer exception instead of MatchError
    :ok = DeliveryPolicies.create(rm_client, policy_json)

    :ok
  end

  defp delete_triggers(rm_client, triggers) do
    if Enum.all?(triggers, &(Trigger.delete(rm_client, &1["name"]) == :ok)) do
      :ok
    else
      {:error, :could_not_delete_triggers}
    end
  end

  defp delivery_policy_matches?(existing, required) do
    contains?(normalize_policy(existing), normalize_policy(required))
  end

  defp normalize_policy(policy) do
    policy
    |> update_in(["retry_times"], &(&1 || 0))
    |> update_in(["prefetch_count"], &(&1 || 0))
    |> sort_error_handlers()
  end

  defp sort_error_handlers(delivery_policy) do
    error_handlers =
      delivery_policy
      |> Map.get("error_handlers", [])
      |> Enum.sort_by(&Map.get(&1, "on"))

    Map.put(delivery_policy, "error_handlers", error_handlers)
  end

  defp list_triggers_that_reference_policy(rm_client, policy_name) do
    with {:ok, %{"data" => trigger_names}} <- Trigger.list(rm_client) do
      triggers_that_reference_policy =
        trigger_names
        |> Enum.map(fn trigger_name ->
          {:ok, trigger} = Trigger.fetch_by_name(rm_client, trigger_name)
          trigger
        end)
        |> Enum.filter(&(&1["policy"] == policy_name))

      {:ok, triggers_that_reference_policy}
    end
  end

  defp update_trigger!(rm_client, name, trigger_json) do
    # Triggers don't have a way to update them, so we delete it and install it again

    # TODO: crash with a nicer exception instead of MatchError
    :ok = Trigger.delete(rm_client, name)
    :ok = install_trigger!(rm_client, trigger_json)

    :ok
  end

  defp install_trigger!(rm_client, trigger_json) do
    # TODO: crash with a nicer exception instead of MatchError
    :ok = Trigger.create(rm_client, trigger_json)

    :ok
  end

  defp trigger_matches?(existing, required) do
    contains?(normalize_defaults(existing), normalize_defaults(required))
  end

  defp normalize_defaults(trigger) do
    trigger
    |> drop_if_default(["action", "ignore_ssl_errors"], false)
    |> drop_if_default(["action", "http_static_headers"], %{})
    |> sort_simple_triggers()
  end

  defp sort_simple_triggers(trigger) do
    simple_triggers =
      trigger
      |> Map.get("simple_triggers", [])
      |> Enum.sort_by(&Map.get(&1, "interface_name"))

    Map.put(trigger, "simple_triggers", simple_triggers)
  end

  defp drop_if_default(trigger, path, default) do
    case pop_in(trigger, path) do
      {^default, no_default_trigger} -> no_default_trigger
      {_not_default, _} -> trigger
    end
  end

  def fetch_astarte_version(rm_client) do
    with {:ok, %{"data" => version}} <- RealmManagement.Version.get(rm_client) do
      {:ok, version}
    end
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
