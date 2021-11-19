#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.DevicesTest do
  use EdgehogWeb.ConnCase

  import Edgehog.AstarteFixtures

  alias Edgehog.Astarte.Device

  describe "applianceModels field" do
    setup do
      cluster = cluster_fixture()

      {:ok, realm: realm_fixture(cluster)}
    end

    @query """
    query ($filter: DeviceFilter) {
      devices(filter: $filter) {
        name
        deviceId
        online
      }
    }
    """
    test "returns empty devices", %{conn: conn} do
      conn = get(conn, "/api", query: @query)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "devices" => []
               }
             }
    end

    test "returns devices if they're present", %{conn: conn, realm: realm} do
      %Device{
        name: name,
        device_id: device_id,
        online: online
      } = device_fixture(realm)

      conn = get(conn, "/api", query: @query)

      assert %{
               "data" => %{
                 "devices" => [device]
               }
             } = json_response(conn, 200)

      assert device["name"] == name
      assert device["deviceId"] == device_id
      assert device["online"] == online
    end

    test "filters devices when a filter is provided", %{conn: conn, realm: realm} do
      %Device{
        name: name,
        device_id: device_id,
        online: online
      } = device_fixture(realm, device_id: "INyxlnmUT3CEJHPAwWMi0A", online: true)

      _device_2 = device_fixture(realm, device_id: "1YmkqsFfSuWDZcYV3ceoBQ", online: false)

      variables = %{filter: %{online: true}}

      conn = post(conn, "/api", query: @query, variables: variables)

      assert %{
               "data" => %{
                 "devices" => [device]
               }
             } = json_response(conn, 200)

      assert device["name"] == name
      assert device["deviceId"] == device_id
      assert device["online"] == online
    end
  end
end
