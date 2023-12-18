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

defmodule Edgehog.Astarte.TriggerTest do
  use Edgehog.DataCase, async: true

  @moduletag :ported_to_ash

  alias Astarte.Client.APIError
  alias Astarte.Client.RealmManagement
  alias Edgehog.Astarte.Trigger

  import Mox
  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  describe "fetch_by_name/2" do
    setup do
      client =
        realm_fixture()
        |> Edgehog.Astarte.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      trigger_name = "edgehog-connection"

      {:ok, client: client, trigger_name: trigger_name}
    end

    test "returns the trigger map if Astarte replies successfully", ctx do
      %{
        client: client,
        trigger_name: trigger_name
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:ok, %{"data" => trigger_map_fixture(name: trigger_name)}}
      end)

      assert {:ok, _trigger} = Trigger.fetch_by_name(client, trigger_name)
    end

    test "returns {:error, :not_found} if Astarte returns a 404", ctx do
      %{
        client: client,
        trigger_name: trigger_name
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:error, api_error(status: 404)}
      end)

      assert {:error, :not_found} = Trigger.fetch_by_name(client, trigger_name)
    end

    # TODO: workaround, remove when the Astarte API does the right thing
    test "returns {:error, :not_found} if Astarte returns a 500", ctx do
      %{
        client: client,
        trigger_name: trigger_name
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:error, api_error(status: 500)}
      end)

      assert {:error, :not_found} = Trigger.fetch_by_name(client, trigger_name)
    end

    test "returns {:error, %APIError{}} if Astarte returns another error", ctx do
      %{
        client: client,
        trigger_name: trigger_name
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:get, fn ^client, ^trigger_name ->
        {:error, api_error(status: 502, message: "Bad Gateway")}
      end)

      assert {:error, %APIError{status: 502, response: response}} =
               Trigger.fetch_by_name(client, trigger_name)

      assert response["errors"]["detail"] == "Bad Gateway"
    end
  end

  describe "create_trigger/2" do
    setup do
      client =
        realm_fixture()
        |> Edgehog.Astarte.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      trigger_map = trigger_map_fixture(name: "edgehog-connection")

      {:ok, client: client, trigger_map: trigger_map}
    end

    test "returns :ok if Astarte replies successfully", ctx do
      %{
        client: client,
        trigger_map: trigger_map
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:create, fn ^client, ^trigger_map ->
        :ok
      end)

      assert :ok = Trigger.create(client, trigger_map)
    end

    test "returns {:error, %APIError{}} if Astarte returns an error", ctx do
      %{
        client: client,
        trigger_map: trigger_map
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:create, fn ^client, ^trigger_map ->
        {:error, api_error(status: 422, message: "Invalid Entity")}
      end)

      assert {:error, %APIError{status: 422, response: response}} =
               Trigger.create(client, trigger_map)

      assert response["errors"]["detail"] == "Invalid Entity"
    end
  end

  describe "delete_trigger/2" do
    setup do
      client =
        realm_fixture()
        |> Edgehog.Astarte.load!(:realm_management_client)
        |> Map.fetch!(:realm_management_client)

      trigger_name = "edgehog-connection"

      {:ok, client: client, trigger_name: trigger_name}
    end

    test "returns :ok if Astarte replies successfully", ctx do
      %{
        client: client,
        trigger_name: trigger_name
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:delete, fn ^client, ^trigger_name ->
        :ok
      end)

      assert :ok = Trigger.delete(client, trigger_name)
    end

    test "returns {:error, %APIError{}} if Astarte returns an error", ctx do
      %{
        client: client,
        trigger_name: trigger_name
      } = ctx

      Edgehog.Astarte.Trigger.MockDataLayer
      |> expect(:delete, fn ^client, ^trigger_name ->
        {:error, api_error(status: 403, message: "Forbidden")}
      end)

      assert {:error, %APIError{status: 403, response: response}} =
               Trigger.delete(client, trigger_name)

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
