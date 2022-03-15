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

defmodule EdgehogWeb.Resolvers.AstarteTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase
  use Edgehog.GeolocationMockCase

  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.BatteryStatus.BatterySlot
  alias Edgehog.Astarte.Device.StorageUsage.StorageUnit

  alias Edgehog.Astarte.Device.{
    BaseImage,
    DeviceStatus,
    OSInfo,
    RuntimeInfo,
    SystemStatus,
    WiFiScanResult
  }

  alias Edgehog.Geolocation
  alias EdgehogWeb.Resolvers.Astarte

  import Edgehog.AstarteFixtures

  describe "devices" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)
      device = device_fixture(realm)

      {:ok, cluster: cluster, realm: realm, device: device}
    end

    test "fetch_device_location/3 returns the location for a device", %{
      device: device
    } do
      assert {:ok, location} = Astarte.fetch_device_location(device, %{}, %{})

      assert %Geolocation{
               accuracy: 12,
               address: "4 Privet Drive, Little Whinging, Surrey, UK",
               latitude: 45.4095285,
               longitude: 11.8788231,
               timestamp: ~U[2021-11-15 11:44:57.432516Z]
             } == location
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
               version: "4.3.1",
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
                 local_area_code: 35632,
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

    test "list_device_capabilities/3 returns the device capabilities info for a device", %{
      device: device
    } do
      Edgehog.Astarte.Device.DeviceStatusMock
      |> expect(:get, fn _appengine_client, _device_id ->
        {:ok,
         %DeviceStatus{
           introspection: %{}
         }}
      end)

      assert {:ok, capabilities} = Astarte.list_device_capabilities(device, %{}, %{})
      assert is_list(capabilities)
    end

    test "list_device_capabilities/3 without DeviceStatus returns empty list", %{
      device: device
    } do
      Edgehog.Astarte.Device.DeviceStatusMock
      |> expect(:get, fn _appengine_client, _device_id ->
        {:error,
         %APIError{
           status: 404,
           response: %{"errors" => %{"detail" => "Device not found"}}
         }}
      end)

      assert {:ok, []} = Astarte.list_device_capabilities(device, %{}, %{})
    end
  end
end
