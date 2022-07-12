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

defmodule Edgehog.Geolocation.Providers.GoogleGeolocationTest do
  use Edgehog.DataCase
  use Edgehog.AstarteMockCase

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Tesla.Mock
  alias Edgehog.Devices
  alias Edgehog.Geolocation.Position
  alias Edgehog.Geolocation.Providers.GoogleGeolocation

  describe "wifi_geolocation" do
    alias Edgehog.Astarte.Device.WiFiScanResult

    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      device =
        device_fixture(realm)
        |> Devices.preload_astarte_resources_for_device()

      {:ok, cluster: cluster, realm: realm, device: device}
    end

    test "geolocate/1 returns error without input AP list", %{device: device} do
      Edgehog.Astarte.Device.WiFiScanResultMock
      |> expect(:get, fn _appengine_client, _device_id -> {:ok, []} end)

      assert GoogleGeolocation.geolocate(device) == {:error, :wifi_scan_results_not_found}
    end

    test "geolocate/1 returns position from AP list", %{device: device} do
      {:ok, timestamp, _offset} = DateTime.from_iso8601("2021-11-11T09:43:54.437Z")

      wifi_scans = [
        %WiFiScanResult{
          channel: 11,
          essid: nil,
          mac_address: "01:23:45:67:89:ab",
          rssi: -43,
          timestamp: timestamp
        }
      ]

      Edgehog.Astarte.Device.WiFiScanResultMock
      |> expect(:get, fn _appengine_client, _device_id -> {:ok, wifi_scans} end)

      response = %{
        "location" => %{
          "lat" => 45.4095285,
          "lng" => 11.8788231
        },
        "accuracy" => 12
      }

      mock(fn
        %{method: :post, url: "https://www.googleapis.com/geolocation/v1/geolocate"} ->
          json(response)
      end)

      assert {:ok, position} = GoogleGeolocation.geolocate(device)

      assert %Position{
               accuracy: 12,
               latitude: 45.4095285,
               longitude: 11.8788231,
               timestamp: ~U[2021-11-11 09:43:54.437Z]
             } ==
               position
    end

    test "geolocate/1 returns error without results from Google", %{device: device} do
      {:ok, timestamp, _offset} = DateTime.from_iso8601("2021-11-11T09:43:54.437Z")

      wifi_scans = [
        %WiFiScanResult{
          channel: 11,
          essid: nil,
          mac_address: "01:23:45:67:89:ab",
          rssi: -43,
          timestamp: timestamp
        }
      ]

      Edgehog.Astarte.Device.WiFiScanResultMock
      |> expect(:get, fn _appengine_client, _device_id -> {:ok, wifi_scans} end)

      response = %{
        "garbage" => "error"
      }

      mock(fn
        %{method: :post, url: "https://www.googleapis.com/geolocation/v1/geolocate"} ->
          json(response)
      end)

      assert {:error, :position_not_found} == GoogleGeolocation.geolocate(device)
    end
  end
end
