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

defmodule Edgehog.Geolocation.Providers.GoogleGeolocation do
  @moduledoc false
  @behaviour Edgehog.Geolocation.GeolocationProvider

  alias Edgehog.Astarte.Device.WiFiScanResult
  alias Edgehog.Config
  alias Edgehog.Devices.Device
  alias Edgehog.EdgehogTeslaClient
  alias Edgehog.Geolocation.Position

  @impl Edgehog.Geolocation.GeolocationProvider
  def geolocate(%Device{} = device) do
    with {:ok, device} <- Ash.load(device, :wifi_scan_results),
         :ok <- validate_wifi_scan_results_exist(device.wifi_scan_results),
         {:ok, wifi_scan_results} <- filter_latest_wifi_scan_results(device.wifi_scan_results) do
      geolocate_wifi(wifi_scan_results)
    end
  end

  defp validate_wifi_scan_results_exist(nil), do: {:error, :wifi_scan_results_not_found}
  defp validate_wifi_scan_results_exist(_), do: :ok

  defp filter_latest_wifi_scan_results([_scan | _] = wifi_scan_results) do
    latest_scan = Enum.max_by(wifi_scan_results, & &1.timestamp, DateTime)

    latest_wifi_scan_results =
      Enum.filter(
        wifi_scan_results,
        &(DateTime.diff(latest_scan.timestamp, &1.timestamp, :second) < 5)
      )

    {:ok, latest_wifi_scan_results}
  end

  defp filter_latest_wifi_scan_results(_wifi_scan_results) do
    {:error, :wifi_scan_results_not_found}
  end

  defp geolocate_wifi([%WiFiScanResult{} | _] = wifi_scan_results) do
    wifi_access_points =
      Enum.map(wifi_scan_results, fn wifi ->
        age =
          wifi.timestamp && DateTime.diff(DateTime.now!("Etc/UTC"), wifi.timestamp, :millisecond)

        %{
          macAddress: wifi.mac_address,
          signalStrength: wifi.rssi,
          channel: wifi.channel,
          age: age
        }
      end)

    body_params = %{
      considerIp: false,
      wifiAccessPoints: wifi_access_points
    }

    with {:ok, api_key} <- Config.google_geolocation_api_key(),
         {:ok, %{body: body}} <-
           EdgehogTeslaClient.post(
             "https://www.googleapis.com/geolocation/v1/geolocate",
             body_params,
             query: [key: api_key]
           ),
         {:coords, %{"location" => %{"lat" => latitude, "lng" => longitude}}}
         when is_number(latitude) and is_number(longitude) <- {:coords, body} do
      timestamp = List.first(wifi_scan_results).timestamp

      position = %Position{
        latitude: latitude,
        longitude: longitude,
        accuracy: body["accuracy"],
        altitude: nil,
        altitude_accuracy: nil,
        heading: nil,
        speed: nil,
        timestamp: timestamp,
        source: """
        GPS position estimated from the list of WiFi access points that the \
        device detected and published on the \
        io.edgehog.devicemanager.WiFiScanResults Astarte interface.\
        """
      }

      {:ok, position}
    else
      {:coords, _} -> {:error, :position_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp geolocate_wifi(_wifi_scan_results) do
    {:error, :position_not_found}
  end
end
