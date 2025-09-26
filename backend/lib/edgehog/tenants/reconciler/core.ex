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

  @minimum_astarte_version_with_policies_support "1.1.1"

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

  def reconcile_trigger!(%Client.RealmManagement{} = client, required_trigger) do
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

  defp delivery_policy_matches?(required, existing) do
    normalize_policy(required) == normalize_policy(existing)
  end

  defp normalize_policy(policy) do
    policy
    |> update_in(["retry_times"], &(&1 || 0))
    |> update_in(["prefetch_count"], &(&1 || 0))
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

  defp trigger_matches?(required, existing) do
    normalize_defaults(required) == normalize_defaults(existing)
  end

  defp normalize_defaults(trigger) do
    trigger
    |> drop_if_default(["action", "ignore_ssl_errors"], false)
    |> drop_if_default(["action", "http_static_headers"], %{})
  end

  defp drop_if_default(trigger, path, default) do
    case pop_in(trigger, path) do
      {^default, no_default_trigger} -> no_default_trigger
      {_not_default, _} -> trigger
    end
  end

  def verify_trigger_delivery_policy_support(rm_client) do
    case RealmManagement.Version.get(rm_client) do
      {:ok, %{"data" => version}} ->
        case Version.compare(version, @minimum_astarte_version_with_policies_support) do
          :lt ->
            {:ok, false}

          _ ->
            {:ok, true}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
