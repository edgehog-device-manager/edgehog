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

defmodule Edgehog.Tenants.ReconcilerTest do
  # This can't be async: true because we're using Mox in global mode
  use Edgehog.DataCase
  use Edgehog.AstarteMockCase

  @moduletag :ported_to_ash

  alias Astarte.Client.APIError
  alias Edgehog.Tenants.Reconciler

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  describe "reconcile_tenant/1" do
    setup do
      # We have to use Mox in global mode because the Interfaces and Triggers mocks are
      # called by an anoymous task launched by the reconciler and we can't easily recover
      # its pid to allow mocks call from it
      Mox.set_mox_global()

      tenant = tenant_fixture()
      _realm = realm_fixture(tenant: tenant)

      %{tenant: tenant}
    end

    test "reconciles interfaces and triggers", %{tenant: tenant} do
      interface_count = Reconciler.Core.list_required_interfaces() |> length()
      trigger_count = Reconciler.Core.list_required_triggers("foo") |> length()

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

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, trigger_count, fn _client, _trigger_name ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, trigger_count, fn _client, _trigger_map ->
        send(test_pid, {:trigger_reconciled, ref})

        :ok
      end)

      assert :ok = Reconciler.reconcile_tenant(tenant)

      1..interface_count
      |> Enum.each(fn _ -> assert_receive {:interface_reconciled, ^ref} end)

      refute_receive {:interface_reconciled, ^ref}

      1..trigger_count
      |> Enum.each(fn _ -> assert_receive {:trigger_reconciled, ^ref} end)

      refute_receive {:trigger_reconciled, ^ref}
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

  describe "cleanup_tenant/1" do
    setup do
      # We have to use Mox in global mode because the Interfaces and Triggers mocks are
      # called by an anoymous task launched by the reconciler and we can't easily recover
      # its pid to allow mocks call from it
      Mox.set_mox_global()

      tenant = tenant_fixture()
      _realm = realm_fixture(tenant: tenant)

      %{tenant: tenant}
    end

    test "deletes triggers", %{tenant: tenant} do
      trigger_count = Reconciler.Core.list_required_triggers("foo") |> length()

      test_pid = self()
      ref = make_ref()

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:delete, trigger_count, fn _client, _trigger_name ->
        send(test_pid, {:trigger_deleted, ref})

        :ok
      end)

      assert :ok = Reconciler.cleanup_tenant(tenant)

      1..trigger_count
      |> Enum.each(fn _ -> assert_receive {:trigger_deleted, ^ref} end)

      refute_receive {:trigger_deleted, ^ref}
    end
  end
end
