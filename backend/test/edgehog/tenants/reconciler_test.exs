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

defmodule Edgehog.Tenants.ReconcilerTest do
  # This can't be async: true because we're using Mox in global mode
  use Edgehog.DataCase

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures
  import ExUnit.CaptureLog

  alias Astarte.Client.APIError
  alias Edgehog.Tenants.Reconciler

  describe "reconcile_all" do
    setup do
      # We have to use Mox in global mode because the Interfaces and Triggers mocks are
      # called by an anoymous task launched by the reconciler and we can't easily recover
      # its pid to allow mocks call from it
      Mox.set_mox_global()

      # Mock the Astarte version check to support trigger delivery policies and
      # device registration and deletion triggers
      Tesla.Mock.mock_global(fn
        %{method: :get, url: url} ->
          if String.ends_with?(url, "/version") do
            %Tesla.Env{status: 200, body: %{"data" => "1.3.0"}}
          else
            %Tesla.Env{status: 404, body: %{"errors" => %{"detail" => "Not found"}}}
          end
      end)

      tenant_1 = tenant_fixture()
      tenant_2 = tenant_fixture()
      _realm_1 = realm_fixture(tenant: tenant_1)
      _realm_2 = realm_fixture(tenant: tenant_2)

      :ok
    end

    test "reconciles interfaces, trigger delivery policies and triggers for all tenants" do
      # Multiply by 2 since we have 2 tenants
      interface_count = length(Reconciler.Core.list_required_interfaces()) * 2
      policy_count = length(Reconciler.Core.list_required_delivery_policies()) * 2
      trigger_count = ("foo" |> Reconciler.Core.list_required_triggers(true) |> length()) * 2

      test_pid = self()
      ref = make_ref()

      Edgehog.Astarte.Interface.MockDataLayer
      |> expect(:get, interface_count, fn _client, _interface_name, _major ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, interface_count, fn _client, _interface_map ->
        send(test_pid, {:interface_reconciled, ref})

        :ok
      end)

      Edgehog.Astarte.DeliveryPolicies.MockDataLayer
      |> expect(:get, policy_count, fn _client, _policy_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, policy_count, fn _client, _policy_map ->
        send(test_pid, {:policy_reconciled, ref})

        :ok
      end)

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, trigger_count, fn _client, _trigger_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, trigger_count, fn _client, _trigger_map ->
        send(test_pid, {:trigger_reconciled, ref})

        :ok
      end)

      # Trigger reconciliation
      send(Reconciler, :reconcile_all)

      Enum.each(1..interface_count, fn _ -> assert_receive {:interface_reconciled, ^ref}, 2000 end)

      Enum.each(1..policy_count, fn _ -> assert_receive {:policy_reconciled, ^ref}, 2000 end)

      Enum.each(1..trigger_count, fn _ -> assert_receive {:trigger_reconciled, ^ref}, 2000 end)
    end
  end

  describe "reconcile_tenant/1" do
    setup do
      # We have to use Mox in global mode because the Interfaces and Triggers mocks are
      # called by an anoymous task launched by the reconciler and we can't easily recover
      # its pid to allow mocks call from it
      Mox.set_mox_global()

      # Mock the Astarte version check to support trigger delivery policies and
      # device registration and deletion triggers
      Tesla.Mock.mock_global(fn
        %{method: :get, url: url} ->
          if String.ends_with?(url, "/version") do
            %Tesla.Env{status: 200, body: %{"data" => "1.3.0"}}
          else
            %Tesla.Env{status: 404, body: %{"errors" => %{"detail" => "Not found"}}}
          end
      end)

      tenant = tenant_fixture()
      _realm = realm_fixture(tenant: tenant)

      %{tenant: tenant}
    end

    test "reconciles interfaces, trigger delivery policies and triggers", %{tenant: tenant} do
      interface_count = length(Reconciler.Core.list_required_interfaces())
      policy_count = length(Reconciler.Core.list_required_delivery_policies())
      trigger_count = "foo" |> Reconciler.Core.list_required_triggers(true) |> length()

      test_pid = self()
      ref = make_ref()

      Edgehog.Astarte.Interface.MockDataLayer
      |> expect(:get, interface_count, fn _client, _interface_name, _major ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, interface_count, fn _client, _interface_map ->
        send(test_pid, {:interface_reconciled, ref})

        :ok
      end)

      Edgehog.Astarte.DeliveryPolicies.MockDataLayer
      |> expect(:get, policy_count, fn _client, _policy_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, policy_count, fn _client, _policy_map ->
        send(test_pid, {:policy_reconciled, ref})

        :ok
      end)

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, trigger_count, fn _client, _trigger_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, trigger_count, fn _client, _trigger_map ->
        send(test_pid, {:trigger_reconciled, ref})

        :ok
      end)

      assert :ok = Reconciler.reconcile_tenant(tenant)

      Enum.each(1..interface_count, fn _ -> assert_receive {:interface_reconciled, ^ref}, 2000 end)

      Enum.each(1..policy_count, fn _ -> assert_receive {:policy_reconciled, ^ref}, 2000 end)

      Enum.each(1..trigger_count, fn _ -> assert_receive {:trigger_reconciled, ^ref}, 2000 end)
    end

    test "skips trigger delivery policies on older Astarte versions", %{tenant: tenant} do
      # Mock the Astarte version check to return an old version
      Tesla.Mock.mock_global(fn
        %{method: :get, url: url} ->
          if String.ends_with?(url, "/version") do
            %Tesla.Env{status: 200, body: %{"data" => "1.0.0"}}
          else
            %Tesla.Env{status: 404, body: %{"errors" => %{"detail" => "Not found"}}}
          end
      end)

      interface_count = length(Reconciler.Core.list_required_interfaces())

      # NOTE: edgehog-registration trigger cannot be installed on astarte
      # 1.0.0, only from astarte 1.3 onwards device registration (and
      # deletion) triggers are supported.
      trigger_count =
        "foo" |> Reconciler.Core.list_required_triggers(false) |> length() |> Kernel.-(1)

      test_pid = self()
      ref = make_ref()

      Edgehog.Astarte.Interface.MockDataLayer
      |> expect(:get, interface_count, fn _client, _interface_name, _major ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, interface_count, fn _client, _interface_map ->
        send(test_pid, {:interface_reconciled, ref})

        :ok
      end)

      # Should not call trigger delivery policies for old versions
      Edgehog.Astarte.DeliveryPolicies.MockDataLayer
      |> expect(:get, 0, fn _client, _policy_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, 0, fn _client, _policy_map ->
        :ok
      end)

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, trigger_count, fn _client, _trigger_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, trigger_count, fn _client, _trigger_map ->
        send(test_pid, {:trigger_reconciled, ref})

        :ok
      end)

      capture_log(fn ->
        assert :ok = Reconciler.reconcile_tenant(tenant)

        Enum.each(1..interface_count, fn _ ->
          assert_receive {:interface_reconciled, ^ref}, 2000
        end)

        Enum.each(1..trigger_count, fn _ -> assert_receive {:trigger_reconciled, ^ref}, 2000 end)
      end)
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
