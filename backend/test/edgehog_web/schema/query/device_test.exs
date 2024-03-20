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

defmodule EdgehogWeb.Schema.Query.DeviceTest do
  use EdgehogWeb.GraphqlCase, async: true

  @moduletag :ported_to_ash

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Devices

  describe "device query" do
    test "returns device if present", %{tenant: tenant} do
      fixture = device_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      device =
        device_query(tenant: tenant, id: id)
        |> extract_result!()

      assert device["name"] == fixture.name
      assert device["deviceId"] == fixture.device_id
      assert device["online"] == fixture.online
    end

    test "queries associated system model", %{tenant: tenant} do
      part_number = "foo123"
      system_model = system_model_fixture(tenant: tenant, part_numbers: [part_number])
      system_model_id = AshGraphql.Resource.encode_relay_id(system_model)

      fixture = device_fixture(tenant: tenant, part_number: part_number)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          systemModel {
            id
            partNumbers {
              partNumber
            }
          }
        }
      }
      """

      device =
        device_query(document: document, tenant: tenant, id: id)
        |> extract_result!()

      assert device["systemModel"]["id"] == system_model_id
      assert device["systemModel"]["partNumbers"] == [%{"partNumber" => part_number}]
    end

    test "returns nil if non existing", %{tenant: tenant} do
      id = non_existing_device_id(tenant)
      result = device_query(tenant: tenant, id: id)
      assert %{data: %{"device" => nil}} = result
    end
  end

  describe "can retrieve from Astarte" do
    setup %{tenant: tenant} do
      fixture = device_fixture(tenant: tenant)
      device_id = fixture.device_id

      id = AshGraphql.Resource.encode_relay_id(fixture)

      %{device: fixture, device_id: device_id, tenant: tenant, id: id}
    end

    test "Base Image info", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.BaseImageMock
      |> expect(:get, fn _client, ^device_id ->
        {:ok, base_image_info_fixture(name: "my-image", version: "1.2.5")}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          baseImage {
            name
            version
          }
        }
      }
      """

      device =
        device_query(document: document, tenant: tenant, id: id)
        |> extract_result!()

      assert device["baseImage"]["name"] == "my-image"
      assert device["baseImage"]["version"] == "1.2.5"
    end

    test "Battery Status", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.BatteryStatusMock
      |> expect(:get, fn _client, ^device_id ->
        {:ok, battery_status_fixture(level_percentage: 29, status: "Charging")}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          deviceId
          batteryStatus {
            levelPercentage
            status
          }
        }
      }
      """

      assert %{"batteryStatus" => [battery_status]} =
               device_query(document: document, tenant: tenant, id: id)
               |> extract_result!()

      assert battery_status["levelPercentage"] == 29
      assert battery_status["status"] == "CHARGING"
    end

    test "Cellular Connection", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.CellularConnectionMock
      |> expect(:get_modem_properties, fn _client, ^device_id ->
        {:ok, modem_properties_fixture(slot: "1", imei: "1234")}
      end)
      |> expect(:get_modem_status, fn _client, ^device_id ->
        {:ok, modem_status_fixture(slot: "1", mobile_country_code: 222)}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          deviceId
          cellularConnection {
            slot
            imei
            mobileCountryCode
          }
        }
      }
      """

      assert %{"cellularConnection" => [modem]} =
               device_query(document: document, tenant: tenant, id: id)
               |> extract_result!()

      assert modem["slot"] == "1"
      assert modem["imei"] == "1234"
      assert modem["mobileCountryCode"] == 222
    end

    test "Hardware Info", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.HardwareInfoMock
      |> expect(:get, fn _client, ^device_id ->
        {:ok, hardware_info_fixture(cpu_architecture: "arm", cpu_model: "ARMv7")}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          hardwareInfo {
            cpuArchitecture
            cpuModel
          }
        }
      }
      """

      device =
        device_query(document: document, tenant: tenant, id: id)
        |> extract_result!()

      assert device["hardwareInfo"]["cpuArchitecture"] == "arm"
      assert device["hardwareInfo"]["cpuModel"] == "ARMv7"
    end

    test "Network Interfaces", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.NetworkInterfaceMock
      |> expect(:get, fn _client, ^device_id ->
        {:ok, network_interfaces_fixture(name: "eth0", technology: "Ethernet")}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          networkInterfaces {
            name
            technology
          }
        }
      }
      """

      %{"networkInterfaces" => [network_interface]} =
        device_query(document: document, tenant: tenant, id: id)
        |> extract_result!()

      assert network_interface["name"] == "eth0"
      assert network_interface["technology"] == "ETHERNET"
    end

    test "OS info", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.OSInfoMock
      |> expect(:get, fn _client, ^device_id ->
        {:ok, os_info_fixture(name: "foo", version: "3.0.0")}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          osInfo {
            name
            version
          }
        }
      }
      """

      device =
        device_query(document: document, tenant: tenant, id: id)
        |> extract_result!()

      assert device["osInfo"]["name"] == "foo"
      assert device["osInfo"]["version"] == "3.0.0"
    end

    test "Runtime info", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.RuntimeInfoMock
      |> expect(:get, fn _client, ^device_id ->
        {:ok, runtime_info_fixture(name: "edgehog-esp32-device", version: "0.7.0")}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          runtimeInfo {
            name
            version
          }
        }
      }
      """

      device =
        device_query(document: document, tenant: tenant, id: id)
        |> extract_result!()

      assert device["runtimeInfo"]["name"] == "edgehog-esp32-device"
      assert device["runtimeInfo"]["version"] == "0.7.0"
    end

    test "Storage Usage", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.StorageUsageMock
      |> expect(:get, fn _client, ^device_id ->
        {:ok, storage_usage_fixture(label: "Flash", free_bytes: 345_678)}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          deviceId
          storageUsage {
            label
            freeBytes
          }
        }
      }
      """

      assert %{"storageUsage" => [storage_unit]} =
               device_query(document: document, tenant: tenant, id: id)
               |> extract_result!()

      assert storage_unit["label"] == "Flash"
      assert storage_unit["freeBytes"] == 345_678
    end

    test "System Status", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.SystemStatusMock
      |> expect(:get, fn _client, ^device_id ->
        {:ok, system_status_fixture(task_count: 193, uptime_milliseconds: 200_159)}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          systemStatus {
            taskCount
            uptimeMilliseconds
          }
        }
      }
      """

      device =
        device_query(document: document, tenant: tenant, id: id)
        |> extract_result!()

      assert device["systemStatus"]["taskCount"] == 193
      assert device["systemStatus"]["uptimeMilliseconds"] == 200_159
    end

    test "WiFi scan results", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.WiFiScanResultMock
      |> expect(:get, fn _client, ^device_id ->
        {:ok, wifi_scan_results_fixture(channel: 7, essid: "MyAP")}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          wifiScanResults {
            channel
            essid
          }
        }
      }
      """

      assert %{"wifiScanResults" => [wifi_scan_result]} =
               device_query(document: document, tenant: tenant, id: id)
               |> extract_result!()

      assert wifi_scan_result["channel"] == 7
      assert wifi_scan_result["essid"] == "MyAP"
    end
  end

  defp non_existing_device_id(tenant) do
    fixture = device_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Devices.destroy!(fixture)

    id
  end

  defp device_query(opts) do
    default_document = """
    query ($id: ID!) {
      device(id: $id) {
        name
        deviceId
        online
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables = %{"id" => id}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"device" => device}} = result
    assert device != nil

    device
  end
end
