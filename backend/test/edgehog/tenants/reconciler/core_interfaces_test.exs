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

defmodule Edgehog.Tenants.Reconciler.CoreInterfacesTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Interface.MockDataLayer
  alias Edgehog.Tenants.Reconciler.Context
  alias Edgehog.Tenants.Reconciler.Core.Interfaces, as: Core

  @astarte_resources_dir "priv/astarte_resources"
  @interfaces_dir "#{@astarte_resources_dir}/interfaces"
  @default_astarte_version "1.3.0-rc.0"

  describe "list_interfaces/0" do
    test "returns the list of required interfaces" do
      interface_files =
        Path.wildcard("#{@interfaces_dir}/*.json")

      interfaces = Core.list_interfaces()

      assert length(interface_files) == length(interfaces)

      for interface <- interfaces do
        interface_name = Map.fetch!(interface, "interface_name")
        assert File.exists?("#{@interfaces_dir}/#{interface_name}.json")
      end
    end
  end

  describe "reconcile_interface!/2" do
    setup do
      tenant = tenant_fixture()

      client =
        [tenant: tenant]
        |> realm_fixture()
        |> Ash.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      name = "io.edgehog.devicemanager.SystemInfo"
      major = 0
      minor = 2

      interface =
        interface_map_fixture(
          name: name,
          major: major,
          minor: minor
        )

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
        interface: interface
      }

      {:ok, test_context}
    end

    test "installs the interface if it's not present", %{context: context, interface: interface} do
      %{
        "interface_name" => name,
        "version_major" => major
      } = interface

      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^name, ^major ->
        {:error, api_error(status: 404)}
      end)
      |> expect(:create, fn ^client, ^interface ->
        :ok
      end)

      refute context
             |> Core.reconcile_interface(interface)
             |> Context.errors?()
    end

    test "doesn't create or update the interface if it's already the correct one", %{
      context: context,
      interface: interface
    } do
      %{
        "interface_name" => name,
        "version_major" => major
      } = interface

      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^name, ^major ->
        {:ok, %{"data" => interface}}
      end)
      |> expect(:create, 0, fn _client, _interface_map -> :ok end)
      |> expect(:update, 0, fn _client, _interface_name, _major, _interface_map -> :ok end)

      refute context
             |> Core.reconcile_interface(interface)
             |> Context.errors?()
    end

    test "doesn't create or update the interface if it has an higher minor version", %{
      context: context,
      interface: interface
    } do
      %{
        "interface_name" => name,
        "version_major" => major,
        "version_minor" => minor
      } = interface

      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^name, ^major ->
        {:ok, %{"data" => put_minor_version(interface, minor + 1)}}
      end)
      |> expect(:create, 0, fn _client, _interface_map -> :ok end)
      |> expect(:update, 0, fn _client, _interface_name, _major, _interface_map -> :ok end)

      refute context
             |> Core.reconcile_interface(interface)
             |> Context.errors?()
    end

    test "updates the interface if it has a lower minor version", %{
      context: context,
      interface: interface
    } do
      %{
        "interface_name" => name,
        "version_major" => major,
        "version_minor" => minor
      } = interface

      %{rm_client: client} = context

      MockDataLayer
      |> expect(:get, fn ^client, ^name, ^major ->
        {:ok, %{"data" => put_minor_version(interface, minor - 1)}}
      end)
      |> expect(:update, fn ^client, ^name, ^major, ^interface ->
        :ok
      end)

      refute context
             |> Core.reconcile_interface(interface)
             |> Context.errors?()
    end

    test "crashes on API errors", %{context: context, interface: interface} do
      expect(MockDataLayer, :get, fn _client, _interface_name, _major ->
        {:error, api_error(status: 500)}
      end)

      assert context
             |> Core.reconcile_interface(interface)
             |> Context.errors?(:interfaces)
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
end
