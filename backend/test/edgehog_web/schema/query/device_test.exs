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

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.OSManagementFixtures

  alias Edgehog.Astarte.Device.DeviceStatusMock

  describe "device query" do
    test "returns device if present", %{tenant: tenant} do
      fixture = device_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      device =
        [tenant: tenant, id: id]
        |> device_query()
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
        [document: document, tenant: tenant, id: id]
        |> device_query()
        |> extract_result!()

      assert device["systemModel"]["id"] == system_model_id
      assert device["systemModel"]["partNumbers"] == [%{"partNumber" => part_number}]
    end

    test "queries associated OTA operations", %{tenant: tenant} do
      fixture = device_fixture(tenant: tenant)

      base_image_url = "https://example.com/ota.bin"

      ota_operation =
        manual_ota_operation_fixture(
          tenant: tenant,
          device_id: fixture.id,
          base_image_url: base_image_url
        )

      ota_operation_id = AshGraphql.Resource.encode_relay_id(ota_operation)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          otaOperations {
            id
            baseImageUrl
          }
        }
      }
      """

      %{"otaOperations" => [ota_operation]} =
        [document: document, tenant: tenant, id: id]
        |> device_query()
        |> extract_result!()

      assert ota_operation["id"] == ota_operation_id
      assert ota_operation["baseImageUrl"] == base_image_url
    end

    test "queries associated application deployments", %{tenant: tenant} do
      fixture = device_fixture(tenant: tenant)

      deployments = [
        Edgehog.ContainersFixtures.deployment_fixture(device_id: fixture.id, tenant: tenant),
        Edgehog.ContainersFixtures.deployment_fixture(device_id: fixture.id, tenant: tenant)
      ]

      deployments = Enum.sort_by(deployments, & &1.release_id)

      _extra_deployment = Edgehog.ContainersFixtures.deployment_fixture(tenant: tenant)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          applicationDeployments {
            edges {
              node {
                releaseId
              }
            } 
          }
        }
      }
      """

      id = AshGraphql.Resource.encode_relay_id(fixture)
      device = [document: document, tenant: tenant, id: id] |> device_query() |> extract_result!()

      results =
        device
        |> get_in(["applicationDeployments", "edges"])
        |> Enum.map(& &1["node"])
        |> Enum.sort_by(& &1["releaseId"])

      for {deployment, result} <- Enum.zip(deployments, results) do
        assert result["releaseId"] == deployment.release_id
      end
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
      expect(Edgehog.Astarte.Device.BaseImageMock, :get, fn _client, ^device_id ->
        {:ok,
         base_image_info_fixture(
           name: "my-image",
           version: "1.2.5",
           build_id: "2022-01-01 12:00:00",
           fingerprint: "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3"
         )}
      end)

      document = """
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

      device =
        [document: document, tenant: tenant, id: id]
        |> device_query()
        |> extract_result!()

      assert device["baseImage"]["name"] == "my-image"
      assert device["baseImage"]["version"] == "1.2.5"
      assert device["baseImage"]["buildId"] == "2022-01-01 12:00:00"

      assert device["baseImage"]["fingerprint"] ==
               "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3"
    end

    test "Battery Status", %{tenant: tenant, id: id, device_id: device_id} do
      expect(Edgehog.Astarte.Device.BatteryStatusMock, :get, fn _client, ^device_id ->
        {:ok,
         battery_status_fixture(
           slot: "Slot 1",
           level_percentage: 29,
           level_absolute_error: 0.2,
           status: "Charging"
         )}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          deviceId
          batteryStatus {
            slot
            levelPercentage
            levelAbsoluteError
            status
          }
        }
      }
      """

      assert %{"batteryStatus" => [battery_status]} =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()

      assert battery_status["slot"] == "Slot 1"
      assert battery_status["levelPercentage"] == 29
      assert battery_status["levelAbsoluteError"] == 0.2
      assert battery_status["status"] == "CHARGING"
    end

    test "Cellular Connection", %{tenant: tenant, id: id, device_id: device_id} do
      Edgehog.Astarte.Device.CellularConnectionMock
      |> expect(:get_modem_properties, fn _client, ^device_id ->
        {:ok,
         modem_properties_fixture(
           slot: "1",
           apn: "company.com",
           imei: "509504877678976",
           imsi: "313460000000001"
         )}
      end)
      |> expect(:get_modem_status, fn _client, ^device_id ->
        {:ok,
         modem_status_fixture(
           slot: "1",
           carrier: "Carrier",
           cell_id: 170_402_199,
           mobile_country_code: 310,
           mobile_network_code: 410,
           local_area_code: 35_632,
           registration_status: "Registered",
           rssi: -60,
           technology: "GSM"
         )}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          deviceId
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

      assert %{"cellularConnection" => [modem]} =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()

      assert modem["slot"] == "1"
      assert modem["apn"] == "company.com"
      assert modem["imei"] == "509504877678976"
      assert modem["imsi"] == "313460000000001"
      assert modem["carrier"] == "Carrier"
      assert modem["cellId"] == 170_402_199
      assert modem["mobileCountryCode"] == 310
      assert modem["mobileNetworkCode"] == 410
      assert modem["localAreaCode"] == 35_632
      assert modem["registrationStatus"] == "REGISTERED"
      assert modem["rssi"] == -60
      assert modem["technology"] == "GSM"
    end

    test "Hardware Info", %{tenant: tenant, id: id, device_id: device_id} do
      expect(Edgehog.Astarte.Device.HardwareInfoMock, :get, fn _client, ^device_id ->
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
        [document: document, tenant: tenant, id: id]
        |> device_query()
        |> extract_result!()

      assert device["hardwareInfo"]["cpuArchitecture"] == "arm"
      assert device["hardwareInfo"]["cpuModel"] == "ARMv7"
    end

    test "Network Interfaces", %{tenant: tenant, id: id, device_id: device_id} do
      expect(Edgehog.Astarte.Device.NetworkInterfaceMock, :get, fn _client, ^device_id ->
        {:ok,
         network_interfaces_fixture(
           name: "eth0",
           mac_address: "00:aa:bb:cc:dd:ee",
           technology: "Ethernet"
         )}
      end)

      document = """
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

      %{"networkInterfaces" => [network_interface]} =
        [document: document, tenant: tenant, id: id]
        |> device_query()
        |> extract_result!()

      assert network_interface["name"] == "eth0"
      assert network_interface["macAddress"] == "00:aa:bb:cc:dd:ee"
      assert network_interface["technology"] == "ETHERNET"
    end

    test "Available containers", %{tenant: tenant, id: id, device_id: device_id} do
      container_id = Ash.UUID.generate()
      status = "Stopped"

      expect(Edgehog.Astarte.Device.AvailableContainersMock, :get, fn _client, ^device_id ->
        {:ok, available_containers_fixture(id: container_id, status: status)}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          availableContainers {
            id
            status
          }
        }
      }
      """

      %{"availableContainers" => [container]} =
        [document: document, tenant: tenant, id: id]
        |> device_query()
        |> extract_result!()

      assert container["id"] == container_id
      assert container["status"] == status
    end

    test "Available volumes", %{tenant: tenant, id: id, device_id: device_id} do
      volume_id = Ash.UUID.generate()
      created = true

      expect(Edgehog.Astarte.Device.AvailableVolumesMock, :get, fn _client, ^device_id ->
        {:ok, available_volumes_fixture(id: volume_id, created: created)}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          availableVolumes {
            id
            created
          }
        }
      }
      """

      %{"availableVolumes" => [volume]} =
        [document: document, tenant: tenant, id: id] |> device_query() |> extract_result!()

      assert volume["id"] == volume_id
      assert volume["created"] == created
    end

    test "OS info", %{tenant: tenant, id: id, device_id: device_id} do
      expect(Edgehog.Astarte.Device.OSInfoMock, :get, fn _client, ^device_id ->
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
        [document: document, tenant: tenant, id: id]
        |> device_query()
        |> extract_result!()

      assert device["osInfo"]["name"] == "foo"
      assert device["osInfo"]["version"] == "3.0.0"
    end

    test "Runtime info", %{tenant: tenant, id: id, device_id: device_id} do
      expect(Edgehog.Astarte.Device.RuntimeInfoMock, :get, fn _client, ^device_id ->
        {:ok,
         runtime_info_fixture(
           name: "edgehog-esp32-device",
           version: "0.7.0",
           environment: "esp-idf v4.3",
           url: "https://github.com/edgehog-device-manager/edgehog-esp32-device"
         )}
      end)

      document = """
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

      device =
        [document: document, tenant: tenant, id: id]
        |> device_query()
        |> extract_result!()

      assert device["runtimeInfo"]["name"] == "edgehog-esp32-device"
      assert device["runtimeInfo"]["version"] == "0.7.0"
      assert device["runtimeInfo"]["environment"] == "esp-idf v4.3"

      assert device["runtimeInfo"]["url"] ==
               "https://github.com/edgehog-device-manager/edgehog-esp32-device"
    end

    test "Storage Usage", %{tenant: tenant, id: id, device_id: device_id} do
      expect(Edgehog.Astarte.Device.StorageUsageMock, :get, fn _client, ^device_id ->
        {:ok, storage_usage_fixture(label: "Flash", free_bytes: 345_678, total_bytes: 348_360_704)}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          deviceId
          storageUsage {
            label
            freeBytes
            totalBytes
          }
        }
      }
      """

      assert %{"storageUsage" => [storage_unit]} =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()

      assert storage_unit["label"] == "Flash"
      assert storage_unit["freeBytes"] == 345_678
      assert storage_unit["totalBytes"] == 348_360_704
    end

    test "System Status", %{tenant: tenant, id: id, device_id: device_id} do
      expect(Edgehog.Astarte.Device.SystemStatusMock, :get, fn _client, ^device_id ->
        {:ok,
         system_status_fixture(
           boot_id: "1c0cf72f-8428-4838-8626-1a748df5b889",
           memory_free_bytes: 166_772,
           task_count: 193,
           uptime_milliseconds: 200_159,
           timestamp: ~U[2021-11-15 11:44:57.432516Z]
         )}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          systemStatus {
            bootId
            memoryFreeBytes
            taskCount
            uptimeMilliseconds
            timestamp
          }
        }
      }
      """

      device =
        [document: document, tenant: tenant, id: id]
        |> device_query()
        |> extract_result!()

      assert device["systemStatus"]["bootId"] == "1c0cf72f-8428-4838-8626-1a748df5b889"
      assert device["systemStatus"]["memoryFreeBytes"] == 166_772
      assert device["systemStatus"]["taskCount"] == 193
      assert device["systemStatus"]["uptimeMilliseconds"] == 200_159
      assert device["systemStatus"]["timestamp"] == "2021-11-15T11:44:57.432516Z"
    end

    test "WiFi scan results", %{tenant: tenant, id: id, device_id: device_id} do
      expect(Edgehog.Astarte.Device.WiFiScanResultMock, :get, fn _client, ^device_id ->
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
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()

      assert wifi_scan_result["channel"] == 7
      assert wifi_scan_result["essid"] == "MyAP"
    end

    test "Queries available images on the device with their status", %{
      tenant: tenant,
      id: id,
      device_id: device_id
    } do
      expect(Edgehog.Astarte.Device.AvailableImagesMock, :get, fn _client, ^device_id ->
        {:ok, available_images_fixture()}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          availableImages {
            id
            pulled
          }
        }
      }
      """

      assert %{"availableImages" => [first_image, second_image]} =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()

      assert first_image["pulled"]
      refute second_image["pulled"]
    end

    test "can read available deployments on the device", %{
      tenant: tenant,
      id: id,
      device_id: device_id
    } do
      expect(Edgehog.Astarte.Device.AvailableDeploymentsMock, :get, fn _client, ^device_id ->
        {:ok, available_deployments_fixture()}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          availableDeployments {
            id
            status
          }
        }
      }
      """

      assert %{"availableDeployments" => [deployment]} =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()

      assert deployment["status"] == "Idle"
    end
  end

  describe "capabilities" do
    alias Edgehog.Tenants.Reconciler.AstarteResources

    setup %{tenant: tenant} do
      fixture = device_fixture(tenant: tenant)
      device_id = fixture.device_id

      id = AshGraphql.Resource.encode_relay_id(fixture)

      %{device: fixture, device_id: device_id, tenant: tenant, id: id}
    end

    test "are all returned with full introspection", ctx do
      %{tenant: tenant, id: id, device_id: device_id} = ctx

      all_interfaces_introspection =
        Map.new(AstarteResources.load_interfaces(), fn %{
                                                         "interface_name" => name,
                                                         "version_major" => major,
                                                         "version_minor" => minor
                                                       } ->
          {name, %Edgehog.Astarte.InterfaceVersion{major: major, minor: minor}}
        end)

      expect(DeviceStatusMock, :get, fn _client, ^device_id ->
        {:ok, device_status_fixture(introspection: all_interfaces_introspection)}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          capabilities
        }
      }
      """

      assert %{"capabilities" => capabilities} =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()

      all_capabilities = [
        "BASE_IMAGE",
        "BATTERY_STATUS",
        "CELLULAR_CONNECTION",
        "COMMANDS",
        "GEOLOCATION",
        "HARDWARE_INFO",
        "LED_BEHAVIORS",
        "NETWORK_INTERFACE_INFO",
        "OPERATING_SYSTEM",
        "REMOTE_TERMINAL",
        "RUNTIME_INFO",
        "SOFTWARE_UPDATES",
        "STORAGE",
        "SYSTEM_INFO",
        "SYSTEM_STATUS",
        "TELEMETRY_CONFIG",
        "WIFI"
      ]

      assert length(capabilities) == length(all_capabilities)

      for capability <- all_capabilities do
        assert capability in capabilities
      end
    end

    test "contain only geolocation for empty introspection", ctx do
      %{tenant: tenant, id: id, device_id: device_id} = ctx

      expect(DeviceStatusMock, :get, fn _client, ^device_id ->
        {:ok, device_status_fixture(introspection: %{})}
      end)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          capabilities
        }
      }
      """

      assert %{"capabilities" => ["GEOLOCATION"]} =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()
    end
  end

  describe "device groups field" do
    import Edgehog.GroupsFixtures

    setup %{tenant: tenant} do
      fixture = device_fixture(tenant: tenant)

      device_id = fixture.device_id

      id = AshGraphql.Resource.encode_relay_id(fixture)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          deviceGroups {
            name
          }
        }
      }
      """

      %{device: fixture, device_id: device_id, tenant: tenant, id: id, document: document}
    end

    test "is empty with no groups", ctx do
      %{tenant: tenant, id: id, document: document} = ctx

      assert %{"deviceGroups" => []} =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()
    end

    test "returns matching group", ctx do
      %{tenant: tenant, id: id, device: device, document: document} = ctx

      _device_with_tag =
        add_tags(device, ["foo"])

      _matching_group =
        device_group_fixture(tenant: tenant, name: "foos", selector: ~s<"foo" in tags>)

      assert %{"deviceGroups" => [%{"name" => "foos"}]} =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()
    end

    test "doesn't return non matching group", ctx do
      %{tenant: tenant, id: id, device: device, document: document} = ctx

      _device_with_tag =
        add_tags(device, ["foo"])

      _non_matching_group =
        device_group_fixture(tenant: tenant, name: "foos", selector: ~s<"bar" in tags>)

      assert %{"deviceGroups" => []} =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()
    end
  end

  describe "device location/position" do
    alias Edgehog.Geolocation.GeocodingProviderMock
    alias Edgehog.Geolocation.GeolocationProviderMock
    alias Edgehog.Geolocation.Location
    alias Edgehog.Geolocation.Position

    setup %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(device)

      document = """
      query ($id: ID!) {
        device(id: $id) {
          position {
            latitude
            longitude
            accuracy
            altitude
            altitudeAccuracy
            heading
            speed
            timestamp
          }
          location {
            formattedAddress
            timestamp
          }
        }
      }
      """

      %{device: device, tenant: tenant, id: id, document: document}
    end

    test "returns both position and location", ctx do
      %{tenant: tenant, id: id, document: document} = ctx

      expect(GeolocationProviderMock, :geolocate, fn _device ->
        {:ok,
         %Position{
           latitude: 45.4095285,
           longitude: 11.8788231,
           accuracy: 12,
           altitude: nil,
           altitude_accuracy: nil,
           heading: nil,
           speed: nil,
           timestamp: ~U[2021-11-15 11:44:57.432516Z]
         }}
      end)

      expect(GeocodingProviderMock, :reverse_geocode, fn _position ->
        {:ok,
         %Location{
           formatted_address: "4 Privet Drive, Little Whinging, Surrey, UK",
           timestamp: ~U[2021-11-15 11:44:57.432516Z]
         }}
      end)

      assert result =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()

      %{
        "latitude" => 45.4095285,
        "longitude" => 11.8788231,
        "accuracy" => 12.0,
        "altitude" => nil,
        "altitudeAccuracy" => nil,
        "heading" => nil,
        "speed" => nil,
        "timestamp" => "2021-11-15T11:44:57.432516Z"
      } = result["position"]

      assert %{
               "formattedAddress" => "4 Privet Drive, Little Whinging, Surrey, UK",
               "timestamp" => "2021-11-15T11:44:57.432516Z"
             } = result["location"]
    end

    test "returns nil when it cannot geolocate the position", ctx do
      %{tenant: tenant, id: id, document: document} = ctx

      expect(GeolocationProviderMock, :geolocate, fn _device ->
        {:error, :position_not_found}
      end)

      assert result =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()

      assert is_nil(result["position"])
      assert is_nil(result["location"])
    end

    test "returns the position even if it cannot reverse geocode it to a location", ctx do
      %{tenant: tenant, id: id, document: document} = ctx

      expect(GeolocationProviderMock, :geolocate, fn _device ->
        {:ok,
         %Position{
           latitude: 45.4095285,
           longitude: 11.8788231,
           accuracy: 12,
           altitude: nil,
           altitude_accuracy: nil,
           heading: nil,
           speed: nil,
           timestamp: ~U[2021-11-15 11:44:57.432516Z]
         }}
      end)

      expect(GeocodingProviderMock, :reverse_geocode, fn _position ->
        {:error, :location_not_found}
      end)

      assert result =
               [document: document, tenant: tenant, id: id]
               |> device_query()
               |> extract_result!()

      assert %{
               "latitude" => 45.4095285,
               "longitude" => 11.8788231,
               "accuracy" => 12.0,
               "altitude" => nil,
               "altitudeAccuracy" => nil,
               "heading" => nil,
               "speed" => nil,
               "timestamp" => "2021-11-15T11:44:57.432516Z"
             } = result["position"]

      assert is_nil(result["location"])
    end
  end

  defp non_existing_device_id(tenant) do
    fixture = device_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

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
