#
# This file is part of Edgehog.
#
# Copyright 2021-2022 SECO Mind Srl
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

defmodule EdgehogWeb.Resolvers.AstarteTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase

  alias Edgehog.Astarte.Device.BatteryStatus.BatterySlot
  alias Edgehog.Astarte.Device.StorageUsage.StorageUnit

  alias Edgehog.Astarte.Device.{
    BaseImage,
    NetworkInterface,
    OSInfo,
    RuntimeInfo,
    SystemStatus,
    WiFiScanResult
  }

  alias Edgehog.Devices

  alias EdgehogWeb.Resolvers.Astarte

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  describe "devices" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      device =
        device_fixture(realm)
        |> Devices.preload_astarte_resources_for_device()

      {:ok, cluster: cluster, realm: realm, device: device}
    end

    test "fetch_storage_usage/3 returns the storage usage for a device", %{
      device: device
    } do
      assert {:ok, storage_units} = Astarte.fetch_storage_usage(device, %{}, %{})

      assert [
               %StorageUnit{
                 label: "Disk 0",
                 total_bytes: 348_360_704,
                 free_bytes: 281_360_704
               }
             ] == storage_units
    end

    test "fetch_system_status/3 returns the system status for a device", %{
      device: device
    } do
      assert {:ok, system_status} = Astarte.fetch_system_status(device, %{}, %{})

      assert %SystemStatus{
               boot_id: "1c0cf72f-8428-4838-8626-1a748df5b889",
               memory_free_bytes: 166_772,
               task_count: 12,
               uptime_milliseconds: 5785,
               timestamp: ~U[2021-11-15 11:44:57.432516Z]
             } == system_status
    end

    test "fetch_wifi_scan_results/3 returns the wifi scans for a device", %{
      device: device
    } do
      assert {:ok, wifi_scan_results} = Astarte.fetch_wifi_scan_results(device, %{}, %{})

      assert [%WiFiScanResult{} | _rest] = wifi_scan_results
    end

    test "fetch_battery_status/3 returns the battery status for a device", %{
      device: device
    } do
      assert {:ok, battery_status} = Astarte.fetch_battery_status(device, %{}, %{})

      assert [
               %BatterySlot{
                 slot: "Slot name",
                 level_percentage: 80.3,
                 level_absolute_error: 0.1,
                 status: "Charging"
               }
               | _rest
             ] = battery_status
    end

    test "fetch_os_info/3 returns the OS info for a device", %{device: device} do
      assert {:ok, os_info} = Astarte.fetch_os_info(device, %{}, %{})

      assert %OSInfo{
               name: "esp-idf",
               version: "v4.3.1"
             } == os_info
    end

    test "fetch_base_image/3 returns the Base Image for a device", %{device: device} do
      assert {:ok, base_image} = Astarte.fetch_base_image(device, %{}, %{})

      assert %BaseImage{
               name: "esp-idf",
               version: "0.1.0",
               build_id: "2022-01-01 12:00:00",
               fingerprint: "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3"
             } == base_image
    end

    test "fetch_cellular_connection/3 returns the cellular_connection for a device", %{
      device: device
    } do
      assert {:ok, cellular_connection} = Astarte.fetch_cellular_connection(device, %{}, %{})

      assert [
               %{
                 slot: "modem_1",
                 apn: "company.com",
                 imei: "509504877678976",
                 imsi: "313460000000001",
                 carrier: "Carrier",
                 cell_id: 170_402_199,
                 mobile_country_code: 310,
                 mobile_network_code: 410,
                 local_area_code: 35_632,
                 registration_status: "Registered",
                 rssi: -60,
                 technology: "GSM"
               },
               %{
                 slot: "modem_2",
                 apn: "internet",
                 imei: "338897112874161",
                 imsi: nil,
                 carrier: nil,
                 cell_id: nil,
                 mobile_country_code: nil,
                 mobile_network_code: nil,
                 local_area_code: nil,
                 registration_status: "NotRegistered",
                 rssi: nil,
                 technology: nil
               },
               %{
                 slot: "modem_3",
                 apn: "internet",
                 imei: "338897112874162",
                 imsi: nil,
                 carrier: nil,
                 cell_id: nil,
                 mobile_country_code: nil,
                 mobile_network_code: nil,
                 local_area_code: nil,
                 registration_status: nil,
                 rssi: nil,
                 technology: nil
               }
             ] == cellular_connection
    end

    test "fetch_runtime_info/3 returns the runtime info for a device", %{device: device} do
      assert {:ok, runtime_info} = Astarte.fetch_runtime_info(device, %{}, %{})

      assert %RuntimeInfo{
               name: "edgehog-esp32-device",
               version: "0.1.0",
               environment: "esp-idf v4.3",
               url: "https://github.com/edgehog-device-manager/edgehog-esp32-device"
             } == runtime_info
    end

    test "fetch_network_interfaces/3 returns the network interfaces for a device", %{
      device: device
    } do
      assert {:ok, network_interfaces} = Astarte.fetch_network_interfaces(device, %{}, %{})

      assert [
               %NetworkInterface{
                 name: "enp2s0",
                 mac_address: "00:aa:bb:cc:dd:ee",
                 technology: "Ethernet"
               },
               %NetworkInterface{
                 name: "wlp3s0",
                 mac_address: "00:aa:bb:cc:dd:ff",
                 technology: "WiFi"
               }
             ] == network_interfaces
    end

    test "set_led_behavior/2 validates requested behavior", %{device: device} do
      valid_behaviors = [:blink, :double_blink, :slow_blink]

      for behavior <- valid_behaviors do
        assert {:ok, %{behavior: behavior}} ==
                 Astarte.set_led_behavior(%{device_id: device.id, behavior: behavior}, %{})
      end

      assert {:error, "Unknown led behavior"} ==
               Astarte.set_led_behavior(%{device_id: device.id, behavior: :invalid_behavior}, %{})
    end

    test "set_led_behavior/2 calls astarte_led_behavior_module with valid device_id", %{
      device: device
    } do
      astarte_device_id = device.device_id

      Edgehog.Astarte.Device.LedBehaviorMock
      |> expect(:post, 1, fn _client, ^astarte_device_id, _behavior -> :ok end)

      assert {:ok, _} = Astarte.set_led_behavior(%{device_id: device.id, behavior: :blink}, %{})
    end
  end
end
