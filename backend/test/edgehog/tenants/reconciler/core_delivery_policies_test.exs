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

defmodule Edgehog.Tenants.Reconciler.CoreDeliveryPoliciesTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  alias Astarte.Client.APIError
  alias Edgehog.Astarte.DeliveryPolicies.MockDataLayer
  alias Edgehog.Tenants.Reconciler.Context
  alias Edgehog.Tenants.Reconciler.Core.DeliveryPolicies, as: Core

  @astarte_resources_dir "priv/astarte_resources"
  @delivery_policies_dir "#{@astarte_resources_dir}/delivery_policies"
  @default_astarte_version "1.3.0-rc.0"

  describe "list_trigger_delivery_policies/0" do
    test "returns the list of required trigger delivery policies" do
      policy_files =
        Path.wildcard("#{@delivery_policies_dir}/*.json.eex")

      policies = Core.list_delivery_policies()

      assert length(policies) == length(policy_files)

      for policy <- policies do
        assert is_map(policy)
        assert Map.has_key?(policy, "name")
        assert is_binary(policy["name"])
      end
    end
  end

  describe "reconcile_delivery_policy/2" do
    setup do
      tenant = tenant_fixture()

      client =
        [tenant: tenant]
        |> realm_fixture()
        |> Ash.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      policy_name = "edgehog-retry-on-server-error"

      policy = %{
        "name" => policy_name,
        "retry_times" => 5,
        "event_ttl" => 3600
      }

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
        policy: policy
      }

      {:ok, test_context}
    end

    test "installs the policy if it's not present", %{context: context, policy: policy} do
      %{"name" => policy_name} = policy

      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^policy_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, fn ^client, ^policy ->
        :ok
      end)

      refute context
             |> Core.reconcile_delivery_policy(policy)
             |> Context.errors?()
    end

    test "doesn't create or delete the policy if it's already the correct one", %{
      context: context,
      policy: policy
    } do
      %{"name" => policy_name} = policy

      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^policy_name ->
        {:ok, %{"data" => policy}}
      end)
      |> expect(:create, 0, fn _client, _policy_map -> :ok end)
      |> expect(:delete, 0, fn _client, _policy_name -> :ok end)

      refute context
             |> Core.reconcile_delivery_policy(policy)
             |> Context.errors?()
    end

    test "doesn't create or delete the policy when astarte adds extra fields", %{
      context: context,
      policy: policy
    } do
      %{"name" => policy_name} = policy

      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^policy_name ->
        {:ok, %{"data" => Map.put(policy, "additional_field", "some-value")}}
      end)
      |> expect(:create, 0, fn _client, _policy_map -> :ok end)
      |> expect(:delete, 0, fn _client, _policy_name -> :ok end)

      refute context
             |> Core.reconcile_delivery_policy(policy)
             |> Context.errors?()
    end

    test "updates the policy if it differs from the required one", %{
      context: context,
      policy: policy
    } do
      %{"name" => policy_name} = policy

      %{rm_client: client} = context

      existing_policy_map = %{
        "name" => policy_name,
        "retry_times" => 3,
        "event_ttl" => 1800
      }

      # Since we can't update policies, they get deleted and recreated
      expect(MockDataLayer, :get, fn ^client, ^policy_name ->
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

      MockDataLayer
      |> expect(:delete, fn ^client, ^policy_name -> :ok end)
      |> expect(:create, fn ^client, ^policy -> :ok end)

      refute context
             |> Core.reconcile_delivery_policy(policy)
             |> Context.errors?()
    end

    test "crashes on API errors", %{
      context: context,
      policy: policy
    } do
      expect(MockDataLayer, :get, fn _client, _policy_name ->
        {:error, api_error(status: 403, message: "Forbidden")}
      end)

      assert {:error, %APIError{}} = Core.reconcile_delivery_policy(context, policy)
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
end
