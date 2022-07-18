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

defmodule Edgehog.Geolocation.Providers.GoogleGeolocation do
  @behaviour Edgehog.Geolocation.GeolocationProvider

  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device.WiFiScanResult
  alias Edgehog.Devices
  alias Edgehog.Devices.Device
  alias Edgehog.Config
  alias Edgehog.Geolocation.Position

  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://www.googleapis.com/geolocation/v1/geolocate"
  plug Tesla.Middleware.JSON

  @impl Edgehog.Geolocation.GeolocationProvider
  def geolocate(%Device{device_id: device_id} = device) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, wifi_scan_results} <- Astarte.fetch_wifi_scan_results(client, device_id),
         {:ok, wifi_scan_results} <- filter_latest_wifi_scan_results(wifi_scan_results) do
      geolocate_wifi(wifi_scan_results)
    end
  end

  defp filter_latest_wifi_scan_results([_scan | _] = wifi_scan_results) do
    latest_scan = Enum.max_by(wifi_scan_results, & &1.timestamp, DateTime)

    latest_wifi_scan_results =
      Enum.filter(
        wifi_scan_results,
        &(DateTime.diff(latest_scan.timestamp, &1.timestamp, :second) < 1)
      )

    {:ok, latest_wifi_scan_results}
  end

  defp filter_latest_wifi_scan_results(_wifi_scan_results) do
    {:error, :wifi_scan_results_not_found}
  end

  defp geolocate_wifi([%WiFiScanResult{} | _] = wifi_scan_results) do
    wifi_access_points =
      Enum.map(wifi_scan_results, fn wifi ->
        %{
          macAddress: wifi.mac_address,
          signalStrength: wifi.rssi,
          channel: wifi.channel
        }
      end)

    body_params = %{
      considerIp: false,
      wifiAccessPoints: wifi_access_points
    }

    with {:ok, api_key} <- Config.google_geolocation_api_key(),
         {:ok, %{body: body}} <- post("", body_params, query: [key: api_key]),
         {:coords, %{"location" => %{"lat" => latitude, "lng" => longitude}}}
         when is_number(latitude) and is_number(longitude) <- {:coords, body} do
      timestamp = List.first(wifi_scan_results).timestamp

      position = %Position{
        latitude: latitude,
        longitude: longitude,
        accuracy: body["accuracy"],
        timestamp: timestamp
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
