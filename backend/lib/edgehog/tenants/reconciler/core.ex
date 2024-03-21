#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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
  alias Astarte.Client
  alias Edgehog.Astarte.Interface
  alias Edgehog.Astarte.Trigger
  alias Edgehog.Tenants.Reconciler.AstarteResources

  @interfaces AstarteResources.load_interfaces()
  @trigger_templates AstarteResources.load_trigger_templates()

  def list_required_interfaces do
    @interfaces
  end

  def list_required_triggers(trigger_url) do
    @trigger_templates
    |> Enum.map(fn template ->
      EEx.eval_string(template, assigns: [trigger_url: trigger_url])
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

  def reconcile_trigger!(%Client.RealmManagement{} = client, required_trigger) do
    %{
      "name" => trigger_name
    } = required_trigger

    case Trigger.fetch_by_name(client, trigger_name) do
      {:ok, existing_trigger} ->
        if existing_trigger != required_trigger do
          update_trigger!(client, trigger_name, required_trigger)
        else
          :ok
        end

      # This intentionally doesn't match on different errors since we want to crash
      # on them, since the tenant reconciliation is isolated in a Task
      # TODO: raise nicer exceptions instead of crashing with CaseClauseError
      {:error, :not_found} ->
        install_trigger!(client, required_trigger)
    end
  end

  def cleanup_trigger(%Client.RealmManagement{} = client, trigger) do
    %{
      "name" => trigger_name
    } = trigger

    Trigger.delete(client, trigger_name)
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

  defp update_trigger!(rm_client, name, trigger_json) do
    # Triggers don't have a way to update them, to we delete it and install it again

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
end
