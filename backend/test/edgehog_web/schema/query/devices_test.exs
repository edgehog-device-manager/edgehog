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
  use Edgehog.AstarteMockCase

  import Edgehog.AppliancesFixtures
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
        applianceModel {
          name
          description {
            locale
            text
          }
        }
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

    test "returns appliance model description with default locale", %{
      conn: conn,
      realm: realm,
      tenant: tenant
    } do
      alias Edgehog.Appliances.ApplianceModel

      hardware_type = hardware_type_fixture()

      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "An appliance"},
        %{locale: "it-IT", text: "Un dispositivo"}
      ]

      %ApplianceModel{name: appliance_model_name, part_numbers: [pn]} =
        appliance_model_fixture(hardware_type, descriptions: descriptions)

      part_number = pn.part_number
      _device = device_fixture(realm, part_number: part_number)

      conn = get(conn, "/api", query: @query)

      assert %{
               "data" => %{
                 "devices" => [device]
               }
             } = json_response(conn, 200)

      assert device["applianceModel"]["name"] == appliance_model_name
      assert device["applianceModel"]["description"]["locale"] == default_locale
      assert device["applianceModel"]["description"]["text"] == "An appliance"
    end

    test "returns appliance model description with explicit locale", %{
      conn: conn,
      realm: realm,
      tenant: tenant
    } do
      alias Edgehog.Appliances.ApplianceModel

      hardware_type = hardware_type_fixture()

      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "An appliance"},
        %{locale: "it-IT", text: "Un dispositivo"}
      ]

      %ApplianceModel{name: appliance_model_name, part_numbers: [pn]} =
        appliance_model_fixture(hardware_type, descriptions: descriptions)

      part_number = pn.part_number

      _device = device_fixture(realm, part_number: part_number)

      conn =
        conn
        |> put_req_header("accept-language", "it-IT")
        |> get("/api", query: @query)

      assert %{
               "data" => %{
                 "devices" => [device]
               }
             } = json_response(conn, 200)

      assert device["applianceModel"]["name"] == appliance_model_name
      assert device["applianceModel"]["description"]["locale"] == "it-IT"
      assert device["applianceModel"]["description"]["text"] == "Un dispositivo"
    end
  end

  describe "device battery status query" do
    setup do
      cluster = cluster_fixture()

      {:ok, realm: realm_fixture(cluster)}
    end

    @battery_status_query """
    query ($id: ID!) {
      device(id: $id) {
        batteryStatus {
          slot
          levelPercentage
          levelAbsoluteError
          status
        }
      }
    }
    """

    test "returns battery status if available", %{conn: conn, realm: realm} do
      %Device{
        id: id
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, "/api", query: @battery_status_query, variables: variables)

      assert %{
               "data" => %{
                 "device" => %{
                   "batteryStatus" => [battery_slot]
                 }
               }
             } = json_response(conn, 200)

      assert battery_slot["slot"] == "Slot name"
      assert battery_slot["levelPercentage"] == 80.3
      assert battery_slot["levelAbsoluteError"] == 0.1
      assert battery_slot["status"] == "CHARGING"
    end
  end

  describe "device OS info query" do
    setup do
      cluster = cluster_fixture()

      {:ok, realm: realm_fixture(cluster)}
    end

    @os_info_query """
    query ($id: ID!) {
      device(id: $id) {
        osInfo {
          name
          version
        }
      }
    }
    """

    test "returns OS info if available", %{conn: conn, realm: realm} do
      %Device{
        id: id
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, "/api", query: @os_info_query, variables: variables)

      assert %{
               "data" => %{
                 "device" => %{
                   "osInfo" => os_info
                 }
               }
             } = json_response(conn, 200)

      assert os_info["name"] == "esp-idf"
      assert os_info["version"] == "v4.3.1"
    end
  end
end
