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

defmodule Edgehog.Astarte.InterfaceTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures

  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Interface
  alias Edgehog.Astarte.Interface.MockDataLayer

  describe "fetch_by_name_and_major/3" do
    setup do
      client =
        realm_fixture()
        |> Ash.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      interface_name = "io.edgehog.devicemanager.SystemInfo"
      major = 0

      {:ok, client: client, interface_name: interface_name, major: major}
    end

    test "returns the interface map if Astarte replies successfully", ctx do
      %{
        client: client,
        interface_name: interface_name,
        major: major
      } = ctx

      expect(MockDataLayer, :get, fn ^client, ^interface_name, ^major ->
        {:ok, %{"data" => interface_map_fixture(name: interface_name, major: major)}}
      end)

      assert {:ok, _interface} = Interface.fetch_by_name_and_major(client, interface_name, major)
    end

    test "returns {:error, :not_found} if Astarte returns a 404", ctx do
      %{
        client: client,
        interface_name: interface_name,
        major: major
      } = ctx

      expect(MockDataLayer, :get, fn ^client, ^interface_name, ^major ->
        {:error, api_error(status: 404)}
      end)

      assert {:error, :not_found} =
               Interface.fetch_by_name_and_major(client, interface_name, major)
    end

    test "returns {:error, %APIError{}} if Astarte returns another error", ctx do
      %{
        client: client,
        interface_name: interface_name,
        major: major
      } = ctx

      expect(MockDataLayer, :get, fn ^client, ^interface_name, ^major ->
        {:error, api_error(status: 500, message: "Internal Server Error")}
      end)

      assert {:error, %APIError{status: 500, response: response}} =
               Interface.fetch_by_name_and_major(client, interface_name, major)

      assert response["errors"]["detail"] == "Internal Server Error"
    end
  end

  describe "create/2" do
    setup do
      client =
        realm_fixture()
        |> Ash.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      interface_map =
        interface_map_fixture(name: "io.edgehog.devicemanager.SystemInfo", major: 1, minor: 2)

      {:ok, client: client, interface_map: interface_map}
    end

    test "returns :ok if Astarte replies successfully", ctx do
      %{
        client: client,
        interface_map: interface_map
      } = ctx

      expect(MockDataLayer, :create, fn ^client, ^interface_map -> :ok end)
      assert :ok = Interface.create(client, interface_map)
    end

    test "returns {:error, %APIError{}} if Astarte returns an error", ctx do
      %{
        client: client,
        interface_map: interface_map
      } = ctx

      expect(MockDataLayer, :create, fn ^client, ^interface_map ->
        {:error, api_error(status: 422, message: "Invalid Entity")}
      end)

      assert {:error, %APIError{status: 422, response: response}} =
               Interface.create(client, interface_map)

      assert response["errors"]["detail"] == "Invalid Entity"
    end
  end

  describe "update/4" do
    setup do
      client =
        realm_fixture()
        |> Ash.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      interface_name = "io.edgehog.devicemanager.SystemInfo"
      major = 0

      interface_map =
        interface_map_fixture(name: "io.edgehog.devicemanager.SystemInfo", major: major, minor: 3)

      ctx = %{
        client: client,
        interface_name: interface_name,
        major: major,
        interface_map: interface_map
      }

      {:ok, ctx}
    end

    test "returns :ok if Astarte replies successfully", ctx do
      %{
        client: client,
        interface_name: interface_name,
        major: major,
        interface_map: interface_map
      } = ctx

      expect(MockDataLayer, :update, fn ^client, ^interface_name, ^major, ^interface_map ->
        :ok
      end)

      assert :ok = Interface.update(client, interface_name, major, interface_map)
    end

    test "returns {:error, %APIError{}} if Astarte returns an error", ctx do
      %{
        client: client,
        interface_name: interface_name,
        major: major,
        interface_map: interface_map
      } = ctx

      expect(MockDataLayer, :update, fn ^client, ^interface_name, ^major, ^interface_map ->
        {:error, api_error(status: 403, message: "Forbidden")}
      end)

      assert {:error, %APIError{status: 403, response: response}} =
               Interface.update(client, interface_name, major, interface_map)

      assert response["errors"]["detail"] == "Forbidden"
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
