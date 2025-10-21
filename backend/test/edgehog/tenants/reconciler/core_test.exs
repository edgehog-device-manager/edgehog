#
# This file is part of Edgehog.
#
# Copyright 2021 - 2025 SECO Mind Srl
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

defmodule Edgehog.Tenants.Reconciler.CoreTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  alias Astarte.Client.APIError
  alias Edgehog.Tenants.Reconciler.Core

  @astarte_resources_dir "priv/astarte_resources"
  @interfaces_dir "#{@astarte_resources_dir}/interfaces"
  @delivery_policies_dir "#{@astarte_resources_dir}/delivery_policies"
  @trigger_templates_dir "#{@astarte_resources_dir}/trigger_templates"

  describe "list_required_interfaces/0" do
    test "returns the list of required interfaces" do
      interface_files =
        Path.wildcard("#{@interfaces_dir}/*.json")

      interfaces = Core.list_required_interfaces()

      assert length(interface_files) == length(interfaces)

      for interface <- interfaces do
        interface_name = Map.fetch!(interface, "interface_name")
        assert File.exists?("#{@interfaces_dir}/#{interface_name}.json")
      end
    end
  end

  describe "list_required_trigger_delivery_policies/0" do
    test "returns the list of required trigger delivery policies" do
      policy_files =
        Path.wildcard("#{@delivery_policies_dir}/*.json.eex")

      policies = Core.list_required_delivery_policies()

      assert length(policies) == length(policy_files)

      for policy <- policies do
        assert is_map(policy)
        assert Map.has_key?(policy, "name")
        assert is_binary(policy["name"])
      end
    end
  end

  describe "list_required_triggers/1" do
    test "returns the list of required triggers, rendering the correct url" do
      trigger_templates =
        Path.wildcard("#{@trigger_templates_dir}/*.json.eex")

      trigger_url = "https://api.edgehog.example/tenants/test/triggers"
      triggers = Core.list_required_triggers(trigger_url)

      assert length(trigger_templates) == length(triggers)

      for trigger <- triggers do
        trigger_name = Map.fetch!(trigger, "name")
        assert File.exists?("#{@trigger_templates_dir}/#{trigger_name}.json.eex")
        assert trigger["action"]["http_url"] == trigger_url
      end
    end
  end

  describe "reconcile_interface!/2" do
    setup do
      client =
        realm_fixture()
        |> Ash.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      interface_name = "io.edgehog.devicemanager.SystemInfo"
      major = 0
      minor = 2

      interface_map =
        interface_map_fixture(
          name: "io.edgehog.devicemanager.SystemInfo",
          major: major,
          minor: minor
        )

      ctx = %{
        client: client,
        interface_name: interface_name,
        major: major,
        minor: minor,
        interface_map: interface_map
      }

      {:ok, ctx}
    end

    test "installs the interface if it's not present", ctx do
      %{
        client: client,
        interface_name: interface_name,
        major: major,
        interface_map: interface_map
      } = ctx

      Edgehog.Astarte.Interface.MockDataLayer
      |> expect(:get, fn ^client, ^interface_name, ^major ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, fn ^client, ^interface_map ->
        :ok
      end)

      assert :ok = Core.reconcile_interface!(client, interface_map)
    end

    test "doesn't create or update the interface if it's already the correct one", ctx do
      %{
        client: client,
        interface_name: interface_name,
        major: major,
        interface_map: interface_map
      } = ctx

      Edgehog.Astarte.Interface.MockDataLayer
      |> expect(:get, fn ^client, ^interface_name, ^major ->
        {:ok, %{"data" => interface_map}}
      end)
      |> expect(:create, 0, fn _client, _interface_map -> :ok end)
      |> expect(:update, 0, fn _client, _interface_name, _major, _interface_map -> :ok end)

      assert :ok = Core.reconcile_interface!(client, interface_map)
    end

    test "doesn't create or update the interface if it has an higher minor version", ctx do
      %{
        client: client,
        interface_name: interface_name,
        major: major,
        minor: minor,
        interface_map: interface_map
      } = ctx

      Edgehog.Astarte.Interface.MockDataLayer
      |> expect(:get, fn ^client, ^interface_name, ^major ->
        {:ok, %{"data" => put_minor_version(interface_map, minor + 1)}}
      end)
      |> expect(:create, 0, fn _client, _interface_map -> :ok end)
      |> expect(:update, 0, fn _client, _interface_name, _major, _interface_map -> :ok end)

      assert :ok = Core.reconcile_interface!(client, interface_map)
    end

    test "updates the interface if it has a lower minor version", ctx do
      %{
        client: client,
        interface_name: interface_name,
        major: major,
        minor: minor,
        interface_map: interface_map
      } = ctx

      Edgehog.Astarte.Interface.MockDataLayer
      |> expect(:get, fn ^client, ^interface_name, ^major ->
        {:ok, %{"data" => put_minor_version(interface_map, minor - 1)}}
      end)
      |> expect(:update, fn ^client, ^interface_name, ^major, ^interface_map ->
        :ok
      end)

      assert :ok = Core.reconcile_interface!(client, interface_map)
    end

    test "crashes on API errors", ctx do
      %{
        client: client,
        interface_map: interface_map
      } = ctx

      expect(Edgehog.Astarte.Interface.MockDataLayer, :get, fn _client, _interface_name, _major ->
        {:error, api_error(status: 500)}
      end)

      assert_raise CaseClauseError, fn ->
        Core.reconcile_interface!(client, interface_map)
      end
    end
  end

  describe "reconcile_delivery_policy!/2" do
    setup do
      client =
        realm_fixture()
        |> Ash.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      policy_name = "edgehog-retry-on-server-error"

      policy_map = %{
        "name" => policy_name,
        "retry_times" => 5,
        "event_ttl" => 3600
      }

      ctx = %{
        client: client,
        policy_name: policy_name,
        policy_map: policy_map
      }

      {:ok, ctx}
    end

    test "installs the policy if it's not present", ctx do
      %{
        client: client,
        policy_name: policy_name,
        policy_map: policy_map
      } = ctx

      Edgehog.Astarte.DeliveryPolicies.MockDataLayer
      |> expect(:get, fn ^client, ^policy_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, fn ^client, ^policy_map ->
        :ok
      end)

      assert :ok = Core.reconcile_delivery_policy!(client, policy_map)
    end

    test "doesn't create or delete the policy if it's already the correct one", ctx do
      %{
        client: client,
        policy_name: policy_name,
        policy_map: policy_map
      } = ctx

      Edgehog.Astarte.DeliveryPolicies.MockDataLayer
      |> expect(:get, fn ^client, ^policy_name ->
        {:ok, %{"data" => policy_map}}
      end)
      |> expect(:create, 0, fn _client, _policy_map -> :ok end)
      |> expect(:delete, 0, fn _client, _policy_name -> :ok end)

      assert :ok = Core.reconcile_delivery_policy!(client, policy_map)
    end

    test "doesn't create or delete the policy when astarte adds extra fields", ctx do
      %{
        client: client,
        policy_name: policy_name,
        policy_map: policy_map
      } = ctx

      Edgehog.Astarte.DeliveryPolicies.MockDataLayer
      |> expect(:get, fn ^client, ^policy_name ->
        {:ok, %{"data" => Map.put(policy_map, "additional_field", "some-value")}}
      end)
      |> expect(:create, 0, fn _client, _policy_map -> :ok end)
      |> expect(:delete, 0, fn _client, _policy_name -> :ok end)

      assert :ok = Core.reconcile_delivery_policy!(client, policy_map)
    end

    test "updates the policy if it differs from the required one", ctx do
      %{
        client: client,
        policy_name: policy_name,
        policy_map: policy_map
      } = ctx

      existing_policy_map = %{
        "name" => policy_name,
        "retry_times" => 3,
        "event_ttl" => 1800
      }

      # Since we can't update policies, they get deleted and recreated
      expect(Edgehog.Astarte.DeliveryPolicies.MockDataLayer, :get, fn ^client, ^policy_name ->
        {:ok, %{"data" => existing_policy_map}}
      end)

      # Mock the trigger listing and deletion that happens when a policy is updated
      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:list, fn ^client ->
        {:ok, %{"data" => [policy_name]}}
      end)
      |> expect(:get, fn ^client, ^policy_name ->
        {:ok, %{"data" => %{"name" => policy_name, "policy" => policy_name}}}
      end)
      |> expect(:delete, fn ^client, ^policy_name -> :ok end)

      Edgehog.Astarte.DeliveryPolicies.MockDataLayer
      |> expect(:delete, fn ^client, ^policy_name -> :ok end)
      |> expect(:create, fn ^client, ^policy_map -> :ok end)

      assert :ok = Core.reconcile_delivery_policy!(client, policy_map)
    end

    test "crashes on API errors", ctx do
      %{
        client: client,
        policy_map: policy_map
      } = ctx

      expect(Edgehog.Astarte.DeliveryPolicies.MockDataLayer, :get, fn _client, _policy_name ->
        {:error, api_error(status: 403, message: "Forbidden")}
      end)

      assert_raise CaseClauseError, fn ->
        Core.reconcile_delivery_policy!(client, policy_map)
      end
    end
  end

  describe "reconcile_trigger!/2" do
    setup do
      tenant = tenant_fixture()

      client =
        [tenant: tenant]
        |> realm_fixture()
        |> Ash.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      trigger_name = "edgehog-connection"

      trigger_map = trigger_map_fixture(name: trigger_name)

      ctx = %{
        tenant: tenant,
        client: client,
        trigger_name: trigger_name,
        trigger_map: trigger_map
      }

      {:ok, ctx}
    end

    test "installs the trigger if it's not present", ctx do
      %{
        tenant: tenant,
        client: client,
        trigger_name: trigger_name,
        trigger_map: trigger_map
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, fn ^client, ^trigger_map ->
        :ok
      end)

      # Use latest astarte version.
      assert :ok = Core.reconcile_trigger!(client, trigger_map, "1.3.0", tenant)
    end

    test "doesn't create or delete the trigger if it's already the correct one", ctx do
      %{
        tenant: tenant,
        client: client,
        trigger_name: trigger_name,
        trigger_map: trigger_map
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:ok, %{"data" => trigger_map}}
      end)
      |> expect(:create, 0, fn _client, _trigger_map -> :ok end)
      |> expect(:delete, 0, fn _client, _trigger_name -> :ok end)

      assert :ok = Core.reconcile_trigger!(client, trigger_map, "1.3.0", tenant)
    end

    test "doesn't create or delete the trigger when Astarte adds extra fields", ctx do
      %{
        tenant: tenant,
        client: client,
        trigger_name: trigger_name,
        trigger_map: trigger_map
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:ok, %{"data" => Map.put(trigger_map, "additional-field", "some-value")}}
      end)
      |> expect(:create, 0, fn _client, _trigger_map -> :ok end)
      |> expect(:delete, 0, fn _client, _trigger_name -> :ok end)

      assert :ok = Core.reconcile_trigger!(client, trigger_map, "1.3.0", tenant)
    end

    test "works even if Astarte returns the trigger without some defaults", ctx do
      %{
        tenant: tenant,
        client: client,
        trigger_name: trigger_name,
        trigger_map: trigger_map
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {_, no_ignore_ssl_errors_map} = pop_in(trigger_map["action"]["ignore_ssl_errors"])
        {_, no_defaults_map} = pop_in(no_ignore_ssl_errors_map["action"]["http_static_headers"])

        {:ok, %{"data" => no_defaults_map}}
      end)
      |> expect(:create, 0, fn _client, _trigger_map -> :ok end)
      |> expect(:delete, 0, fn _client, _trigger_name -> :ok end)

      assert :ok = Core.reconcile_trigger!(client, trigger_map, "1.3.0", tenant)
    end

    test "deletes and recreates the trigger if it differs from the required one", ctx do
      %{
        tenant: tenant,
        client: client,
        trigger_name: trigger_name,
        trigger_map: trigger_map
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:ok, %{"data" => put_trigger_url(trigger_map, "https://other.url.example/triggers")}}
      end)
      |> expect(:delete, fn ^client, ^trigger_name -> :ok end)
      |> expect(:create, fn ^client, ^trigger_map -> :ok end)

      assert :ok = Core.reconcile_trigger!(client, trigger_map, "1.3.0", tenant)
    end

    test "crashes on API errors", ctx do
      %{
        tenant: tenant,
        client: client,
        trigger_map: trigger_map
      } = ctx

      expect(Edgehog.Astarte.Trigger.MockDataLayer, :get, fn _client, _trigger_name ->
        {:error, api_error(status: 502)}
      end)

      assert_raise CaseClauseError, fn ->
        Core.reconcile_trigger!(client, trigger_map, "1.3.0", tenant)
      end
    end
  end

  describe "min_version_matches/1" do
    test "returns true for Astarte versions >=" do
      assert Core.min_version_matches("1.2.0", "1.1.1")
      assert Core.min_version_matches("1.1.1", "1.1.1")
    end

    test "returns false for Astarte versions <" do
      refute Core.min_version_matches("1.1.0", "1.1.1")
    end
  end

  describe "fetch_astarte_version/1" do
    setup do
      client =
        realm_fixture()
        |> Ash.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      %{client: client}
    end

    test "listens for realm management version", %{client: client} do
      # Mock the version endpoint
      Tesla.Mock.mock_global(fn
        %{method: :get, url: url} ->
          if String.ends_with?(url, "/version") do
            %Tesla.Env{status: 200, body: %{"data" => "1.2.0"}}
          else
            %Tesla.Env{status: 404, body: %{"errors" => %{"detail" => "Not found"}}}
          end
      end)

      assert {:ok, "1.2.0"} = Core.fetch_astarte_version(client)
    end

    test "fails if realm management fails", %{client: client} do
      # Mock the version endpoint
      Tesla.Mock.mock_global(fn
        %{method: :get, url: url} ->
          if String.ends_with?(url, "/version") do
            %Tesla.Env{status: 500, body: %{"errors" => %{"detail" => "Internal server error"}}}
          else
            %Tesla.Env{status: 404, body: %{"errors" => %{"detail" => "Not found"}}}
          end
      end)

      assert {:error, _} = Core.fetch_astarte_version(client)
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

  defp put_minor_version(interface_map, minor) do
    Map.put(interface_map, "version_minor", minor)
  end

  defp put_trigger_url(trigger_map, url) do
    put_in(trigger_map["action"]["http_url"], url)
  end
end
