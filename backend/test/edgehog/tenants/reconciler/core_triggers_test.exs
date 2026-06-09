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

defmodule Edgehog.Tenants.Reconciler.CoreTriggersTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Trigger.MockDataLayer
  alias Edgehog.Tenants.Reconciler.Context
  alias Edgehog.Tenants.Reconciler.Core.Triggers, as: Core

  @astarte_resources_dir "priv/astarte_resources"
  @trigger_templates_dir "#{@astarte_resources_dir}/trigger_templates"
  @default_astarte_version "1.3.0-rc.0"

  describe "list_triggers/1" do
    test "returns the list of required triggers, rendering the correct url" do
      trigger_templates =
        Path.wildcard("#{@trigger_templates_dir}/*.json.eex")

      trigger_url = "https://api.edgehog.example/tenants/test/triggers"
      triggers = Core.list_triggers(trigger_url)

      assert length(trigger_templates) == length(triggers)

      for trigger <- triggers do
        trigger_name = Map.fetch!(trigger, "name")
        assert File.exists?("#{@trigger_templates_dir}/#{trigger_name}.json.eex")
        assert trigger["action"]["http_url"] == trigger_url
      end
    end
  end

  describe "reconcile_trigger/2" do
    setup do
      tenant = tenant_fixture()

      client =
        [tenant: tenant]
        |> realm_fixture()
        |> Ash.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      trigger_name = "edgehog-connection"

      trigger = trigger_map_fixture(name: trigger_name)

      trigger_fun = Application.fetch_env!(:edgehog, :tenant_to_trigger_url_fun)

      context = %{
        rm_client: client,
        tenant: tenant,
        astarte_version: @default_astarte_version,
        tenant_to_trigger_url_fun: trigger_fun,
        errors: []
      }

      test_context = %{
        context: context,
        trigger: trigger
      }

      {:ok, test_context}
    end

    test "installs the trigger if it's not present", %{context: context, trigger: trigger} do
      %{"name" => trigger_name} = trigger

      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, fn ^client, ^trigger ->
        :ok
      end)

      refute context
             |> Core.reconcile_trigger(trigger)
             |> Context.errors?(:triggers)
    end

    test "doesn't create or delete the trigger if it's already the correct one", %{
      context: context,
      trigger: trigger
    } do
      %{"name" => trigger_name} = trigger

      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:ok, %{"data" => trigger}}
      end)
      |> expect(:create, 0, fn _client, _trigger_map -> :ok end)
      |> expect(:delete, 0, fn _client, _trigger_name -> :ok end)

      refute context
             |> Core.reconcile_trigger(trigger)
             |> Context.errors?(:triggers)
    end

    test "doesn't create or delete the trigger when Astarte adds extra fields", %{
      context: context,
      trigger: trigger
    } do
      %{"name" => trigger_name} = trigger
      %{rm_client: client} = context

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:ok, %{"data" => Map.put(trigger, "additional-field", "some-value")}}
      end)
      |> expect(:create, 0, fn _client, _trigger_map -> :ok end)
      |> expect(:delete, 0, fn _client, _trigger_name -> :ok end)

      refute context
             |> Core.reconcile_trigger(trigger)
             |> Context.errors?(:triggers)
    end

    test "works even if Astarte returns the trigger without some defaults", %{
      context: context,
      trigger: trigger
    } do
      %{"name" => trigger_name} = trigger
      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {_, no_ignore_ssl_errors_map} = pop_in(trigger["action"]["ignore_ssl_errors"])
        {_, no_defaults_map} = pop_in(no_ignore_ssl_errors_map["action"]["http_static_headers"])

        {:ok, %{"data" => no_defaults_map}}
      end)
      |> expect(:create, 0, fn _client, _trigger_map -> :ok end)
      |> expect(:delete, 0, fn _client, _trigger_name -> :ok end)

      refute context
             |> Core.reconcile_trigger(trigger)
             |> Context.errors?(:triggers)
    end

    test "deletes and recreates the trigger if it differs from the required one", %{
      context: context,
      trigger: trigger
    } do
      %{"name" => trigger_name} = trigger
      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:ok, %{"data" => put_trigger_url(trigger, "https://other.url.example/triggers")}}
      end)
      |> expect(:delete, fn ^client, ^trigger_name -> :ok end)
      |> expect(:create, fn ^client, ^trigger -> :ok end)

      refute context
             |> Core.reconcile_trigger(trigger)
             |> Context.errors?(:triggers)
    end

    test "crashes on API errors", %{context: context, trigger: trigger} do
      expect(MockDataLayer, :get, fn _client, _trigger_name ->
        {:error, api_error(status: 502)}
      end)

      assert context
             |> Core.reconcile_trigger(trigger)
             |> Context.errors?(:triggers)
    end
  end

  defp api_error(opts) do
    status = Keyword.get(opts, :status, 500)
    message = Keyword.get(opts, :message, "Generic error")

    %APIError{
      status: status,
      response: %{"errors" => %{"detail" => message}}
    }
  end

  defp put_trigger_url(trigger_map, url) do
    put_in(trigger_map["action"]["http_url"], url)
  end
end
