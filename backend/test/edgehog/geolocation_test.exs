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

defmodule Edgehog.GeolocationTest do
  use Edgehog.DataCase
  use Edgehog.AstarteMockCase
  use Edgehog.GeolocationMockCase

  alias Edgehog.Geolocation

  describe "device_location" do
    import Edgehog.AstarteFixtures
    alias Edgehog.Astarte.Device.DeviceStatus

    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)
      device = device_fixture(realm)

      {:ok, cluster: cluster, realm: realm, device: device}
    end

    test "fetch_location/1 returns coordinates, timestamp, and address for a device", %{
      device: device
    } do
      assert {:ok, location} = Geolocation.fetch_location(device)

      assert %Geolocation{
               accuracy: 12,
               address: "4 Privet Drive, Little Whinging, Surrey, UK",
               latitude: 45.4095285,
               longitude: 11.8788231,
               timestamp: ~U[2021-11-15 11:44:57.432516Z]
             } == location
    end

    test "fetch_location/1 fails without wifi scans and device IP", %{
      device: device
    } do
      Edgehog.Astarte.Device.WiFiScanResultMock
      |> expect(:get, fn _appengine_client, _device_id -> {:ok, []} end)

      Edgehog.Astarte.Device.DeviceStatusMock
      |> expect(:get, fn _appengine_client, _device_id ->
        {:ok,
         %DeviceStatus{
           last_connection: nil,
           last_disconnection: nil,
           online: false,
           last_seen_ip: nil
         }}
      end)

      assert {:error, :device_coordinates_not_found} = Geolocation.fetch_location(device)
    end

    test "fetch_location/1 prefers geolocation from wifi scans", %{
      device: device
    } do
      Edgehog.Geolocation.WiFiGeolocationProviderMock
      |> expect(:geolocate, fn _wifi_scans ->
        {:ok, %{accuracy: 1, latitude: 1, longitude: 1}}
      end)

      assert {:ok, location} = Geolocation.fetch_location(device)

      assert %Geolocation{
               accuracy: 1,
               latitude: 1,
               longitude: 1
             } = location
    end

    test "fetch_location/1 uses IP geolocation when WiFi geolocation fails", %{
      device: device
    } do
      Edgehog.Geolocation.WiFiGeolocationProviderMock
      |> expect(:geolocate, fn _wifi_scans ->
        {:error, :coordinates_not_found}
      end)

      Edgehog.Geolocation.IPGeolocationProviderMock
      |> expect(:geolocate, fn _ip_address ->
        {:ok, %{accuracy: 2, latitude: 2, longitude: 2}}
      end)

      assert {:ok, location} = Geolocation.fetch_location(device)

      assert %Geolocation{
               accuracy: 2,
               latitude: 2,
               longitude: 2
             } = location
    end

    test "fetch_location/1 returns coordinates even if geocoding fails", %{
      device: device
    } do
      Edgehog.Geolocation.GeocodingProviderMock
      |> expect(:reverse_geocode, fn _coordinates -> {:error, :address_not_found} end)

      assert {:ok, location} = Geolocation.fetch_location(device)

      assert %Geolocation{
               accuracy: 12,
               address: nil,
               latitude: 45.4095285,
               longitude: 11.8788231,
               timestamp: ~U[2021-11-15 11:44:57.432516Z]
             } == location
    end
  end
end
