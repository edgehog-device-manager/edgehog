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

defmodule Edgehog.Geolocation.Providers.GoogleGeolocationTest do
  use Edgehog.DataCase

  import Tesla.Mock
  alias Edgehog.Geolocation.Providers.GoogleGeolocation

  describe "wifi_geolocation" do
    alias Edgehog.Astarte.Device.WiFiScanResult

    test "geolocate/1 returns error without input AP list" do
      assert GoogleGeolocation.geolocate(nil) == {:error, :coordinates_not_found}
      assert GoogleGeolocation.geolocate([]) == {:error, :coordinates_not_found}
    end

    test "geolocate/1 returns coordinates from AP list" do
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

      assert {:ok, coordinates} = GoogleGeolocation.geolocate(wifi_scans)

      assert %{accuracy: 12, latitude: 45.4095285, longitude: 11.8788231} ==
               coordinates
    end

    test "geolocate/1 returns error without results from Google" do
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

      response = %{
        "garbage" => "error"
      }

      mock(fn
        %{method: :post, url: "https://www.googleapis.com/geolocation/v1/geolocate"} ->
          json(response)
      end)

      assert {:error, :coordinates_not_found} == GoogleGeolocation.geolocate(wifi_scans)
    end
  end
end
