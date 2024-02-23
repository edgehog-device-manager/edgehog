#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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
  use EdgehogWeb.GraphqlCase, async: true

  @moduletag :ported_to_ash

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  describe "devices query" do
    test "returns empty devices", %{tenant: tenant} do
      assert [] == devices_query(tenant: tenant) |> extract_result!()
    end

    test "returns devices if they're present", %{tenant: tenant} do
      fixture = device_fixture(tenant: tenant)

      assert [device] = devices_query(tenant: tenant) |> extract_result!()

      assert device["name"] == fixture.name
      assert device["deviceId"] == fixture.device_id
      assert device["online"] == fixture.online
    end

    test "queries associated system models", %{tenant: tenant} do
      part_number_1 = "foo123"
      _ = system_model_fixture(tenant: tenant, part_numbers: [part_number_1])

      part_number_2 = "bar456"
      _ = system_model_fixture(tenant: tenant, part_numbers: [part_number_2])

      _ = device_fixture(tenant: tenant, part_number: part_number_1)
      _ = device_fixture(tenant: tenant, part_number: part_number_2)
      _ = device_fixture(tenant: tenant, part_number: part_number_2)
      _ = device_fixture(tenant: tenant)

      document = """
      query {
        devices {
          systemModel {
            id
            partNumbers {
              partNumber
            }
          }
        }
      }
      """

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      assert Enum.count(devices, fn device ->
               %{"partNumber" => part_number_1} in (device["systemModel"]["partNumbers"] || [])
             end) == 1

      assert Enum.count(devices, fn device ->
               %{"partNumber" => part_number_2} in (device["systemModel"]["partNumbers"] || [])
             end) == 2

      assert Enum.count(devices, fn device -> device["systemModel"] == nil end) == 1
    end

    test "allows filtering", %{tenant: tenant} do
      _ = device_fixture(tenant: tenant, name: "online-1", online: true)
      _ = device_fixture(tenant: tenant, name: "offline-1", online: false)
      _ = device_fixture(tenant: tenant, name: "online-2", online: true)

      filter = %{"online" => %{"eq" => true}}

      devices =
        devices_query(tenant: tenant, filter: filter)
        |> extract_result!()

      assert length(devices) == 2
      assert "online-1" in Enum.map(devices, & &1["name"])
      assert "online-2" in Enum.map(devices, & &1["name"])
      refute "offline-1" in Enum.map(devices, & &1["name"])
    end

    test "allows sorting", %{tenant: tenant} do
      _ = device_fixture(tenant: tenant, name: "b")
      _ = device_fixture(tenant: tenant, name: "a")
      _ = device_fixture(tenant: tenant, name: "c")

      sort = %{"field" => "NAME", "order" => "DESC"}

      assert [%{"name" => "c"}, %{"name" => "b"}, %{"name" => "a"}] =
               devices_query(tenant: tenant, sort: sort)
               |> extract_result!()
    end
  end

  describe "can retrieve from Astarte" do
    setup %{tenant: tenant} do
      fixture_1 = device_fixture(tenant: tenant)
      device_id_1 = fixture_1.device_id
      fixture_2 = device_fixture(tenant: tenant)
      device_id_2 = fixture_2.device_id

      %{device_id_1: device_id_1, device_id_2: device_id_2, tenant: tenant}
    end

    test "Base Image info", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.BaseImageMock
      |> expect(:get, fn _client, ^device_id_1 ->
        {:ok, os_info_fixture(name: "foo", version: "1.0.0")}
      end)
      |> expect(:get, fn _client, ^device_id_2 ->
        {:ok, os_info_fixture(name: "bar", version: "2.0.0")}
      end)

      document = """
      query {
        devices {
          deviceId
          baseImage {
            name
            version
          }
        }
      }
      """

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      assert %{
               "deviceId" => device_id_1,
               "baseImage" => %{"name" => "foo", "version" => "1.0.0"}
             } in devices

      assert %{
               "deviceId" => device_id_2,
               "baseImage" => %{"name" => "bar", "version" => "2.0.0"}
             } in devices
    end

    test "Battery Status", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.BatteryStatusMock
      |> expect(:get, fn _client, ^device_id_1 ->
        {:ok, battery_status_fixture(level_percentage: 29.0, status: "Charging")}
      end)
      |> expect(:get, fn _client, ^device_id_2 ->
        {:ok, battery_status_fixture(level_percentage: 81.0, status: "Discharging")}
      end)

      document = """
      query {
        devices {
          deviceId
          batteryStatus {
            levelPercentage
            status
          }
        }
      }
      """

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      assert %{
               "deviceId" => device_id_1,
               "batteryStatus" => [%{"levelPercentage" => 29.0, "status" => "CHARGING"}]
             } in devices

      assert %{
               "deviceId" => device_id_2,
               "batteryStatus" => [%{"levelPercentage" => 81.0, "status" => "DISCHARGING"}]
             } in devices
    end

    test "Cellular Connection", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.CellularConnectionMock
      |> expect(:get_modem_properties, fn _client, ^device_id_1 ->
        {:ok, modem_properties_fixture(slot: "1", imei: "1234")}
      end)
      |> expect(:get_modem_status, fn _client, ^device_id_1 ->
        {:ok, modem_status_fixture(slot: "1", mobile_country_code: 222)}
      end)
      |> expect(:get_modem_properties, fn _client, ^device_id_2 ->
        {:ok, modem_properties_fixture(slot: "2", imei: "5678")}
      end)
      |> expect(:get_modem_status, fn _client, ^device_id_2 ->
        {:ok, modem_status_fixture(slot: "2", mobile_country_code: 622)}
      end)

      document = """
      query {
        devices {
          deviceId
          cellularConnection {
            slot
            imei
            mobileCountryCode
          }
        }
      }
      """

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      assert %{
               "deviceId" => device_id_1,
               "cellularConnection" => [
                 %{"slot" => "1", "imei" => "1234", "mobileCountryCode" => 222}
               ]
             } in devices

      assert %{
               "deviceId" => device_id_2,
               "cellularConnection" => [
                 %{"slot" => "2", "imei" => "5678", "mobileCountryCode" => 622}
               ]
             } in devices
    end

    test "Hardware Info", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.HardwareInfoMock
      |> expect(:get, fn _client, ^device_id_1 ->
        {:ok, hardware_info_fixture(cpu_architecture: "arm", cpu_model: "ARMv7")}
      end)
      |> expect(:get, fn _client, ^device_id_2 ->
        {:ok, hardware_info_fixture(cpu_architecture: "Xtensa", cpu_model: "ESP32")}
      end)

      document = """
      query {
        devices {
          deviceId
          hardwareInfo {
            cpuArchitecture
            cpuModel
          }
        }
      }
      """

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      assert %{
               "deviceId" => device_id_1,
               "hardwareInfo" => %{"cpuArchitecture" => "arm", "cpuModel" => "ARMv7"}
             } in devices

      assert %{
               "deviceId" => device_id_2,
               "hardwareInfo" => %{"cpuArchitecture" => "Xtensa", "cpuModel" => "ESP32"}
             } in devices
    end

    test "Network Interfaces", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.NetworkInterfaceMock
      |> expect(:get, fn _client, ^device_id_1 ->
        {:ok, network_interfaces_fixture(name: "eth0", technology: "Ethernet")}
      end)
      |> expect(:get, fn _client, ^device_id_2 ->
        {:ok, network_interfaces_fixture(name: "wlan0", technology: "WiFi")}
      end)

      document = """
      query {
        devices {
          deviceId
          networkInterfaces {
            name
            technology
          }
        }
      }
      """

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      assert %{
               "deviceId" => device_id_1,
               "networkInterfaces" => [%{"name" => "eth0", "technology" => "ETHERNET"}]
             } in devices

      assert %{
               "deviceId" => device_id_2,
               "networkInterfaces" => [%{"name" => "wlan0", "technology" => "WIFI"}]
             } in devices
    end

    test "OS info", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.OSInfoMock
      |> expect(:get, fn _client, ^device_id_1 ->
        {:ok, os_info_fixture(name: "foo_1", version: "1.0.0")}
      end)
      |> expect(:get, fn _client, ^device_id_2 ->
        {:ok, os_info_fixture(name: "foo_2", version: "2.0.0")}
      end)

      document = """
      query {
        devices {
          deviceId
          osInfo {
            name
            version
          }
        }
      }
      """

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      assert %{
               "deviceId" => device_id_1,
               "osInfo" => %{"name" => "foo_1", "version" => "1.0.0"}
             } in devices

      assert %{
               "deviceId" => device_id_2,
               "osInfo" => %{"name" => "foo_2", "version" => "2.0.0"}
             } in devices
    end

    test "queries WiFi scan results", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.WiFiScanResultMock
      |> expect(:get, fn _client, ^device_id_1 ->
        {:ok, wifi_scan_results_fixture(connected: true, rssi: -40)}
      end)
      |> expect(:get, fn _client, ^device_id_2 ->
        {:ok, wifi_scan_results_fixture(connected: false, rssi: -78)}
      end)

      document = """
      query {
        devices {
          deviceId
          wifiScanResults {
            connected
            rssi
          }
        }
      }
      """

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      assert %{
               "deviceId" => device_id_1,
               "wifiScanResults" => [%{"connected" => true, "rssi" => -40}]
             } in devices

      assert %{
               "deviceId" => device_id_2,
               "wifiScanResults" => [%{"connected" => false, "rssi" => -78}]
             } in devices
    end
  end

  defp devices_query(opts) do
    default_document =
      """
      query Devices($filter: DeviceFilterInput, $sort: [DeviceSortInput]) {
        devices(filter: $filter, sort: $sort) {
          name
          deviceId
          online
          lastConnection
          lastDisconnection
          serialNumber
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    variables =
      %{
        "filter" => opts[:filter],
        "sort" => opts[:sort] || []
      }

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"devices" => devices}} = result
    assert devices != nil

    devices
  end
end
