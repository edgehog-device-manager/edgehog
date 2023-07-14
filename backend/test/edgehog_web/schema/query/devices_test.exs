#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.DevicesTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase

  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.AstarteFixtures

  alias Edgehog.Devices
  alias Edgehog.Devices.Device
  alias Edgehog.Groups.DeviceGroup

  describe "systemModels field" do
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
        systemModel {
          name
          description
        }
      }
    }
    """
    test "returns empty devices", %{conn: conn, api_path: api_path} do
      conn = get(conn, api_path, query: @query)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "devices" => []
               }
             }
    end

    test "returns devices if they're present", %{conn: conn, api_path: api_path, realm: realm} do
      %Device{
        name: name,
        device_id: device_id,
        online: online
      } = device_fixture(realm)

      conn = get(conn, api_path, query: @query)

      assert %{
               "data" => %{
                 "devices" => [device]
               }
             } = json_response(conn, 200)

      assert device["name"] == name
      assert device["deviceId"] == device_id
      assert device["online"] == online
    end

    test "filters devices when a filter is provided", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      %Device{
        name: name,
        device_id: device_id,
        online: online
      } = device_fixture(realm, device_id: "INyxlnmUT3CEJHPAwWMi0A", online: true)

      _device_2 = device_fixture(realm, device_id: "1YmkqsFfSuWDZcYV3ceoBQ", online: false)

      variables = %{filter: %{online: true}}

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "devices" => [device]
               }
             } = json_response(conn, 200)

      assert device["name"] == name
      assert device["deviceId"] == device_id
      assert device["online"] == online
    end

    test "filters devices with tag", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      {:ok,
       %Device{
         name: name,
         device_id: device_id,
         online: online
       }} =
        device_fixture(realm, device_id: "INyxlnmUT3CEJHPAwWMi0A")
        |> Devices.update_device(%{tags: ["foobar"]})

      _device_2 = device_fixture(realm, device_id: "1YmkqsFfSuWDZcYV3ceoBQ")

      variables = %{filter: %{tag: "foo"}}

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "devices" => [device]
               }
             } = json_response(conn, 200)

      assert device["name"] == name
      assert device["deviceId"] == device_id
      assert device["online"] == online
    end

    test "returns system model description with default locale", %{
      conn: conn,
      api_path: api_path,
      realm: realm,
      tenant: tenant
    } do
      alias Edgehog.Devices.SystemModel

      hardware_type = hardware_type_fixture()

      default_locale = tenant.default_locale

      description = %{default_locale => "A system model", "it-IT" => "Un modello di sistema"}

      %SystemModel{name: system_model_name, part_numbers: [pn]} =
        system_model_fixture(hardware_type, description: description)

      part_number = pn.part_number
      _device = device_fixture(realm, part_number: part_number)

      conn = get(conn, api_path, query: @query)

      assert %{
               "data" => %{
                 "devices" => [device]
               }
             } = json_response(conn, 200)

      assert device["systemModel"]["name"] == system_model_name
      assert device["systemModel"]["description"] == "A system model"
    end

    test "returns system model description with explicit locale", %{
      conn: conn,
      api_path: api_path,
      realm: realm,
      tenant: tenant
    } do
      alias Edgehog.Devices.SystemModel

      hardware_type = hardware_type_fixture()

      default_locale = tenant.default_locale

      description = %{default_locale => "A system model", "it-IT" => "Un modello di sistema"}

      %SystemModel{name: system_model_name, part_numbers: [pn]} =
        system_model_fixture(hardware_type, description: description)

      part_number = pn.part_number

      _device = device_fixture(realm, part_number: part_number)

      conn =
        conn
        |> put_req_header("accept-language", "it-IT")
        |> get(api_path, query: @query)

      assert %{
               "data" => %{
                 "devices" => [device]
               }
             } = json_response(conn, 200)

      assert device["systemModel"]["name"] == system_model_name
      assert device["systemModel"]["description"] == "Un modello di sistema"
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

    test "returns battery status if available", %{conn: conn, api_path: api_path, realm: realm} do
      %Device{
        id: id
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @battery_status_query, variables: variables)

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

    test "returns OS info if available", %{conn: conn, api_path: api_path, realm: realm} do
      %Device{
        id: id
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @os_info_query, variables: variables)

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

  describe "device Base Image query" do
    setup do
      cluster = cluster_fixture()

      {:ok, realm: realm_fixture(cluster)}
    end

    @base_image_query """
    query ($id: ID!) {
      device(id: $id) {
        baseImage {
          name
          version
          buildId
          fingerprint
        }
      }
    }
    """

    test "returns OS info if available", %{conn: conn, api_path: api_path, realm: realm} do
      %Device{
        id: id
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @base_image_query, variables: variables)

      assert %{
               "data" => %{
                 "device" => %{
                   "baseImage" => base_image
                 }
               }
             } = json_response(conn, 200)

      assert base_image["name"] == "esp-idf"
      assert base_image["version"] == "0.1.0"
      assert base_image["buildId"] == "2022-01-01 12:00:00"

      assert base_image["fingerprint"] ==
               "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3"
    end
  end

  describe "device cellular connection query" do
    setup do
      cluster = cluster_fixture()

      {:ok, realm: realm_fixture(cluster)}
    end

    @cellular_connection_query """
    query ($id: ID!) {
      device(id: $id) {
        cellularConnection {
          slot
          apn
          imei
          imsi
          carrier
          cellId
          mobileCountryCode
          mobileNetworkCode
          localAreaCode
          registrationStatus
          rssi
          technology
        }
      }
    }
    """

    test "returns cellular connection if available", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      %Device{
        id: id
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @cellular_connection_query, variables: variables)

      assert %{
               "data" => %{
                 "device" => %{
                   "cellularConnection" => [modem1, modem2, modem3]
                 }
               }
             } = json_response(conn, 200)

      assert modem1["slot"] == "modem_1"
      assert modem1["apn"] == "company.com"
      assert modem1["imei"] == "509504877678976"
      assert modem1["imsi"] == "313460000000001"
      assert modem1["carrier"] == "Carrier"
      assert modem1["cellId"] == 170_402_199
      assert modem1["mobileCountryCode"] == 310
      assert modem1["mobileNetworkCode"] == 410
      assert modem1["localAreaCode"] == 35_632
      assert modem1["registrationStatus"] == "REGISTERED"
      assert modem1["rssi"] == -60
      assert modem1["technology"] == "GSM"

      assert modem2["slot"] == "modem_2"
      assert modem2["apn"] == "internet"
      assert modem2["imei"] == "338897112874161"
      assert modem2["registrationStatus"] == "NOT_REGISTERED"

      assert modem3["slot"] == "modem_3"
      assert modem3["apn"] == "internet"
      assert modem3["imei"] == "338897112874162"
      assert modem3["registrationStatus"] == nil
    end
  end

  describe "device runtime info query" do
    setup do
      cluster = cluster_fixture()

      {:ok, realm: realm_fixture(cluster)}
    end

    @runtime_info_query """
    query ($id: ID!) {
      device(id: $id) {
        runtimeInfo {
          name
          version
          environment
          url
        }
      }
    }
    """

    test "returns runtime info if available", %{conn: conn, api_path: api_path, realm: realm} do
      %Device{
        id: id
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @runtime_info_query, variables: variables)

      assert %{
               "data" => %{
                 "device" => %{
                   "runtimeInfo" => runtime_info
                 }
               }
             } = json_response(conn, 200)

      assert runtime_info["name"] == "edgehog-esp32-device"
      assert runtime_info["version"] == "0.1.0"
      assert runtime_info["environment"] == "esp-idf v4.3"

      assert runtime_info["url"] ==
               "https://github.com/edgehog-device-manager/edgehog-esp32-device"
    end
  end

  describe "device network interfaces query" do
    setup do
      cluster = cluster_fixture()

      {:ok, realm: realm_fixture(cluster)}
    end

    @network_interfaces_query """
    query ($id: ID!) {
      device(id: $id) {
        networkInterfaces {
          name
          macAddress
          technology
        }
      }
    }
    """

    test "returns network interfaces if available", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      %Device{
        id: id
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @network_interfaces_query, variables: variables)

      assert %{
               "data" => %{
                 "device" => %{
                   "networkInterfaces" => [interface1, interface2]
                 }
               }
             } = json_response(conn, 200)

      assert interface1["name"] == "enp2s0"
      assert interface1["macAddress"] == "00:aa:bb:cc:dd:ee"
      assert interface1["technology"] == "ETHERNET"

      assert interface2["name"] == "wlp3s0"
      assert interface2["macAddress"] == "00:aa:bb:cc:dd:ff"
      assert interface2["technology"] == "WIFI"
    end
  end

  describe "devices device_groups query" do
    setup do
      cluster = cluster_fixture()

      {:ok, realm: realm_fixture(cluster)}
    end

    @groups_query """
    query {
      devices {
        id
        deviceGroups {
          id
          handle
        }
      }
    }
    """

    test "returns the device groups", %{conn: conn, api_path: api_path, realm: realm} do
      %DeviceGroup{id: foos_id} =
        device_group_fixture(name: "Foos", handle: "foos", selector: ~s<"foo" in tags>)

      foos_global_id = Absinthe.Relay.Node.to_global_id(:device_group, foos_id, EdgehogWeb.Schema)

      %DeviceGroup{id: bars_id} =
        device_group_fixture(name: "Bars", handle: "bars", selector: ~s<"bar" in tags>)

      bars_global_id = Absinthe.Relay.Node.to_global_id(:device_group, bars_id, EdgehogWeb.Schema)

      {:ok, %Device{id: device_1_id}} =
        device_fixture(realm)
        |> Devices.update_device(%{tags: ["foo", "bar"]})

      device_1_global_id =
        Absinthe.Relay.Node.to_global_id(:device, device_1_id, EdgehogWeb.Schema)

      {:ok, %Device{id: device_2_id}} =
        device_fixture(realm, name: "Device 2", device_id: "b6jrAd4QReC9PTolINIbIQ")
        |> Devices.update_device(%{tags: ["foo"]})

      device_2_global_id =
        Absinthe.Relay.Node.to_global_id(:device, device_2_id, EdgehogWeb.Schema)

      %Device{id: device_3_id} =
        device_fixture(realm, name: "Device 3", device_id: "nBfAIS4bTa2D4siBfedeHA")

      device_3_global_id =
        Absinthe.Relay.Node.to_global_id(:device, device_3_id, EdgehogWeb.Schema)

      conn = get(conn, api_path, query: @groups_query)

      assert %{
               "data" => %{
                 "devices" => devices
               }
             } = json_response(conn, 200)

      assert length(devices) == 3
      device_1 = Enum.find(devices, &(&1["id"] == device_1_global_id))
      assert length(device_1["deviceGroups"]) == 2
      assert %{"handle" => "foos", "id" => foos_global_id} in device_1["deviceGroups"]
      assert %{"handle" => "bars", "id" => bars_global_id} in device_1["deviceGroups"]

      device_2 = Enum.find(devices, &(&1["id"] == device_2_global_id))
      assert [%{"handle" => "foos", "id" => foos_global_id}] == device_2["deviceGroups"]

      device_3 = Enum.find(devices, &(&1["id"] == device_3_global_id))
      assert [] == device_3["deviceGroups"]
    end
  end
end
