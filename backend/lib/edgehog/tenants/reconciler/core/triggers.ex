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

defmodule Edgehog.Tenants.Reconciler.Core.Triggers do
  @moduledoc """
  The reconciler core part for triggers.

  The main entrypoint is `reconcile/1`

  `reconcile/1` takes as input a context and tries to install all the available
  triggers based on previous steps results:

  - if delivery policies are compatible builds triggers accordingly
  - if astarte is compatible with device registration and deletion triggers,
    then it tries to install such triggers.
  """

  alias Edgehog.Astarte.Trigger
  alias Edgehog.Tenants.Reconciler.AstarteResources
  alias Edgehog.Tenants.Reconciler.Context

  require Logger

  @trigger_templates AstarteResources.load_trigger_templates()
  @minimum_astarte_version_with_registration_triggers_support "1.3.0-rc.0"
  @astarte_1_3_triggers [
    "device_registered",
    "device_deletion_started",
    "device_deletion_finished"
  ]
  @error_section :triggers

  @doc """
  Lists all the available triggers.

  These triggers are `EEx` evaluated and can either be constructed with or without policies (by default, without).
  """
  def list_triggers(trigger_url, with_policies \\ false) do
    Enum.map(@trigger_templates, fn template ->
      template
      |> EEx.eval_string(
        assigns: [
          trigger_url: trigger_url,
          can_use_trigger_delivery_policy: with_policies
        ]
      )
      |> Jason.decode!()
    end)
  end

  @doc """
  Uninstalls trigger from the given context.

  This function takes a context (with a realm management client embedded) and
  queries astarte to uninstall the given triggers

  Trigger deletion happens by name, only the trigger name is actually used to
  delete the trigger, hence, be careful what you wish for!
  """
  def delete(context, triggers) do
    Enum.reduce_while(triggers, context, &delete_reducer/2)
  end

  defp delete_reducer(trigger, context) do
    %{rm_client: rm_client} = context

    %{"name" => name} = trigger

    case Trigger.delete(rm_client, name) do
      :ok -> {:cont, context}
      {:error, error} -> {:halt, {:error, error}}
    end
  end

  @doc """
  Reconciles the triggers for a given context.

  If there is any error in the interfaces scope we cannot guarantee that
  interfaces have been installed. Hence, we cannot install triggers.

  This also checks the compatibility with device deletion and registration
  triggers.
  """
  def reconcile(%{astarte_version: version} = context) do
    context
    |> Context.add_context(device_registration_and_deletion_compatible: compatible?(version))
    |> reconcile_triggers()
  end

  defp compatible?(version) do
    Version.compare(@minimum_astarte_version_with_registration_triggers_support, version) != :gt
  end

  defp reconcile_triggers(context) do
    %{
      delivery_policies_compatible: with_policies,
      tenant_to_trigger_url_fun: trigger_fun,
      tenant: tenant
    } = context

    %{tenant: %{slug: slug}} = context

    Logger.info(
      "Reconciling triggers for tenant #{slug}. Compatibility with delivery policies: #{inspect(with_policies)}"
    )

    case Context.errors?(context, :interfaces) do
      # Context is ok, let's install triggers!
      false ->
        trigger_url = trigger_fun.(tenant)
        triggers = list_triggers(trigger_url, with_policies)
        Enum.reduce_while(triggers, context, &reduce/2)

      # Context is cursed ! don't poison the logs with pointless errors for trigger installation
      true ->
        Logger.warning("""
        Skipping trigger reconciliation for tenant #{tenant.slug}.

        Interfaces installation error list was not empty, meaning that interface
        installation was not completed. Check the above logs to understand what
        went wrong!
        """)

        context
    end
  end

  defp reduce(trigger, context) do
    case reconcile_trigger(context, trigger) do
      {:error, error} -> {:halt, {:error, error}}
      context -> {:cont, context}
    end
  end

  def reconcile_trigger(context, trigger) do
    %{rm_client: rm_client, astarte_version: version} = context
    %{"name" => name} = trigger

    case trigger_compatible?(context, trigger) do
      {:incompatible, min_version} ->
        warning_log = """
        Warning: skipping installation for trigger '#{name}'.

        The minimum required version of astarte for this trigger is astarte
        #{min_version}, but the  version found is #{version}.
        """

        Logger.warning(warning_log)

        context

      :compatible ->
        installed_trigger = Trigger.fetch_by_name(rm_client, name)
        update_or_install(context, trigger, installed_trigger)
    end
  end

  defp update_or_install(context, trigger, {:ok, old_trigger}) do
    if matches?(old_trigger, trigger),
      do: context,
      else: update(context, trigger)
  end

  defp update_or_install(context, trigger, {:error, :not_found}),
    do: install(context, trigger)

  defp update_or_install(context, trigger, {:error, error}) do
    %{tenant: %{slug: slug}} = context
    %{"name" => name} = trigger

    log_error = """
    Error while reconciling the trigger '#{name}' for tenant '#{slug}'.

    Deletion responded with an error: #{inspect(error)}.

    Is the connection with astarte ok?
    """

    Logger.error(log_error)

    Context.add_error(context, @error_section, error)
  end

  defp update(context, trigger) do
    %{rm_client: rm_client, tenant: %{slug: slug}} = context
    %{"name" => name} = trigger

    case Trigger.delete(rm_client, name) do
      :ok ->
        install(context, trigger)

      {:error, error} ->
        log_error = """
        Error while updating the trigger '#{name}' for tenant '#{slug}'.

        Deletion responded with an error: #{inspect(error)}.

        Is the connection with astarte ok?

        This is not really recoverable, bubbling up.
        """

        Logger.error(log_error)

        {:error, error}
    end
  end

  defp install(context, trigger) do
    %{rm_client: rm_client, tenant: %{slug: slug}} = context
    %{"name" => name} = trigger

    case Trigger.create(rm_client, trigger) do
      :ok ->
        context

      {:error, error} ->
        log_error = """
        Error while installing the trigger '#{name}' for tenant '#{slug}'.

        Installation answered with an error: #{inspect(error)}.

        Is the connection with astarte ok?

        This is not really recoverable, bubbling up.
        """

        Logger.error(log_error)

        {:error, error}
    end
  end

  defp matches?(existing, required) do
    contains?(normalize_defaults(existing), normalize_defaults(required))
  end

  defp normalize_defaults(trigger) do
    trigger
    |> drop_if_default(["action", "ignore_ssl_errors"], false)
    |> drop_if_default(["action", "http_static_headers"], %{})
    |> sort_simple_triggers()
  end

  defp drop_if_default(trigger, path, default) do
    case pop_in(trigger, path) do
      {^default, no_default_trigger} -> no_default_trigger
      {_not_default, _} -> trigger
    end
  end

  defp sort_simple_triggers(trigger) do
    simple_triggers =
      trigger
      |> Map.get("simple_triggers", [])
      |> Enum.sort_by(&Map.get(&1, "interface_name"))

    Map.put(trigger, "simple_triggers", simple_triggers)
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

  # entry point for trigger compatibility. In the future we might want to add
  # additional checks here. Keeping as a single call for forward compatibility
  defp trigger_compatible?(context, trigger),
    do: check_astarte_1_3(context, trigger)

  defp check_astarte_1_3(context, trigger) do
    %{"simple_triggers" => simple_triggers} = trigger

    compatible? =
      Enum.any?(simple_triggers, fn simple_trigger ->
        simple_trigger["on"] in @astarte_1_3_triggers
      end)

    case compatible? do
      true ->
        check_astarte_version(
          context,
          @minimum_astarte_version_with_registration_triggers_support
        )

      false ->
        :compatible
    end
  end

  defp check_astarte_version(context, min_version) do
    %{astarte_version: astarte_version} = context

    case Version.compare(min_version, astarte_version) do
      :gt -> {:incompatible, min_version}
      _ -> :compatible
    end
  end
end
