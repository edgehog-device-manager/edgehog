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
      |> expect(:get, 2, fn
        _client, ^device_id_1 ->
          {:ok, base_image_info_fixture(name: "foo", version: "1.0.0")}

        _client, ^device_id_2 ->
          {:ok, base_image_info_fixture(name: "bar", version: "2.0.0")}
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
      |> expect(:get, 2, fn
        _client, ^device_id_1 ->
          {:ok, battery_status_fixture(level_percentage: 29.0, status: "Charging")}

        _client, ^device_id_2 ->
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
      |> expect(:get_modem_properties, 2, fn
        _client, ^device_id_1 ->
          {:ok, modem_properties_fixture(slot: "1", imei: "1234")}

        _client, ^device_id_2 ->
          {:ok, modem_properties_fixture(slot: "2", imei: "5678")}
      end)
      |> expect(:get_modem_status, 2, fn
        _client, ^device_id_1 ->
          {:ok, modem_status_fixture(slot: "1", mobile_country_code: 222)}

        _client, ^device_id_2 ->
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
      |> expect(:get, 2, fn
        _client, ^device_id_1 ->
          {:ok, hardware_info_fixture(cpu_architecture: "arm", cpu_model: "ARMv7")}

        _client, ^device_id_2 ->
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
      |> expect(:get, 2, fn
        _client, ^device_id_1 ->
          {:ok, network_interfaces_fixture(name: "eth0", technology: "Ethernet")}

        _client, ^device_id_2 ->
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
      |> expect(:get, 2, fn
        _client, ^device_id_1 ->
          {:ok, os_info_fixture(name: "foo_1", version: "1.0.0")}

        _client, ^device_id_2 ->
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

    test "Runtime info", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.RuntimeInfoMock
      |> expect(:get, 2, fn
        _client, ^device_id_1 ->
          {:ok, runtime_info_fixture(name: "edgehog-esp32-device", version: "0.7.0")}

        _client, ^device_id_2 ->
          {:ok, runtime_info_fixture(name: "edgehog-device-runtime", version: "0.8.0")}
      end)

      document = """
      query {
        devices {
          deviceId
          runtimeInfo {
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
               "runtimeInfo" => %{"name" => "edgehog-esp32-device", "version" => "0.7.0"}
             } in devices

      assert %{
               "deviceId" => device_id_2,
               "runtimeInfo" => %{"name" => "edgehog-device-runtime", "version" => "0.8.0"}
             } in devices
    end

    test "Storage Usage", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.StorageUsageMock
      |> expect(:get, 2, fn
        _client, ^device_id_1 ->
          {:ok, storage_usage_fixture(label: "Disk 0", free_bytes: 1_000_000)}

        _client, ^device_id_2 ->
          {:ok, storage_usage_fixture(label: "Disk 1", free_bytes: 5_999_999)}
      end)

      document = """
      query {
        devices {
          deviceId
          storageUsage {
            label
            freeBytes
          }
        }
      }
      """

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      assert %{
               "deviceId" => device_id_1,
               "storageUsage" => [%{"label" => "Disk 0", "freeBytes" => 1_000_000}]
             } in devices

      assert %{
               "deviceId" => device_id_2,
               "storageUsage" => [%{"label" => "Disk 1", "freeBytes" => 5_999_999}]
             } in devices
    end

    test "System Status", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.SystemStatusMock
      |> expect(:get, 2, fn
        _client, ^device_id_1 ->
          {:ok, system_status_fixture(task_count: 193, uptime_milliseconds: 200_159)}

        _client, ^device_id_2 ->
          {:ok, system_status_fixture(task_count: 21, uptime_milliseconds: 10_249)}
      end)

      document = """
      query {
        devices {
          deviceId
          systemStatus {
            taskCount
            uptimeMilliseconds
          }
        }
      }
      """

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      assert %{
               "deviceId" => device_id_1,
               "systemStatus" => %{"taskCount" => 193, "uptimeMilliseconds" => 200_159}
             } in devices

      assert %{
               "deviceId" => device_id_2,
               "systemStatus" => %{"taskCount" => 21, "uptimeMilliseconds" => 10_249}
             } in devices
    end

    test "queries WiFi scan results", ctx do
      %{tenant: tenant, device_id_1: device_id_1, device_id_2: device_id_2} = ctx

      Edgehog.Astarte.Device.WiFiScanResultMock
      |> expect(:get, 2, fn
        _client, ^device_id_1 ->
          {:ok, wifi_scan_results_fixture(connected: true, rssi: -40)}

        _client, ^device_id_2 ->
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

  describe "device groups field" do
    import Edgehog.GroupsFixtures

    setup %{tenant: tenant} do
      fixture_1 = device_fixture(tenant: tenant)
      device_id_1 = fixture_1.device_id
      fixture_2 = device_fixture(tenant: tenant)
      device_id_2 = fixture_2.device_id

      document = """
      query {
        devices {
          deviceId
          deviceGroups {
            name
          }
        }
      }
      """

      %{
        device_1: fixture_1,
        device_id_1: device_id_1,
        device_2: fixture_2,
        device_id_2: device_id_2,
        tenant: tenant,
        document: document
      }
    end

    test "is empty with no groups", ctx do
      %{tenant: tenant, document: document} = ctx

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      Enum.each(devices, &assert(&1["deviceGroups"] == []))
    end

    test "returns matching groups", ctx do
      %{
        tenant: tenant,
        device_1: device_1,
        device_id_1: device_id_1,
        device_2: device_2,
        device_id_2: device_id_2,
        document: document
      } = ctx

      _device_1_with_tags =
        device_1
        |> add_tags(["foo", "bar"])

      _device_2_with_tags =
        device_2
        |> add_tags(["bar", "baz"])

      _ = device_group_fixture(tenant: tenant, name: "foos", selector: ~s<"foo" in tags>)
      _ = device_group_fixture(tenant: tenant, name: "bars", selector: ~s<"bar" in tags>)
      _ = device_group_fixture(tenant: tenant, name: "bazs", selector: ~s<"baz" in tags>)

      devices =
        devices_query(document: document, tenant: tenant)
        |> extract_result!()

      device_1_groups =
        Enum.find_value(devices, &(&1["deviceId"] == device_id_1 && &1["deviceGroups"]))

      assert length(device_1_groups) == 2
      assert %{"name" => "foos"} in device_1_groups
      assert %{"name" => "bars"} in device_1_groups

      device_2_groups =
        Enum.find_value(devices, &(&1["deviceId"] == device_id_2 && &1["deviceGroups"]))

      assert length(device_2_groups) == 2
      assert %{"name" => "bars"} in device_2_groups
      assert %{"name" => "bazs"} in device_2_groups
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
