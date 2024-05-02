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

defmodule Edgehog.Geolocation.Providers.IPBase do
  @behaviour Edgehog.Geolocation.GeolocationProvider

  alias Edgehog.Config
  alias Edgehog.Devices.Device
  alias Edgehog.Geolocation.Position

  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://api.ipbase.com/v2/info"
  plug Tesla.Middleware.JSON

  @impl Edgehog.Geolocation.GeolocationProvider
  def geolocate(%Device{} = device) do
    with {:ok, device} <- Ash.load(device, :device_status),
         :ok <- validate_device_status_exists(device.device_status) do
      %{
        last_seen_ip: last_seen_ip,
        last_connection: last_connection,
        last_disconnection: last_disconnection
      } =
        device.device_status

      last_seen_timestamp =
        [last_connection, last_disconnection]
        |> Enum.reject(&is_nil/1)
        |> Enum.sort({:desc, DateTime})
        |> List.first(DateTime.utc_now())

      geolocate_ip(last_seen_ip, last_seen_timestamp)
    end
  end

  defp validate_device_status_exists(_nil), do: {:error, :device_status_not_found}
  defp validate_device_status_exists(_), do: :ok

  defp geolocate_ip(nil, _timestamp) do
    {:error, :position_not_found}
  end

  defp geolocate_ip(ip_address, timestamp) do
    with {:ok, api_key} <- Config.ipbase_api_key(),
         {:ok, %{body: body}} <- get("", query: [apikey: api_key, ip: ip_address]),
         {:ok, geolocation_data} <- parse_response_body(body) do
      position = %Position{
        latitude: geolocation_data.latitude,
        longitude: geolocation_data.longitude,
        accuracy: geolocation_data.accuracy,
        altitude: nil,
        altitude_accuracy: nil,
        heading: nil,
        speed: nil,
        timestamp: timestamp
      }

      {:ok, position}
    end
  end

  defp parse_response_body(body) do
    with %{"data" => data} <- body,
         %{"location" => location} <- data,
         %{"latitude" => latitude, "longitude" => longitude}
         when is_number(latitude) and is_number(longitude) <- location do
      zip = Map.get(location, "zip")
      city = location |> Map.get("city", %{}) |> Map.get("name")
      region = location |> Map.get("region", %{}) |> Map.get("name")
      country = location |> Map.get("country", %{}) |> Map.get("name")

      address =
        [city, zip, region, country]
        |> Enum.reject(&(is_nil(&1) or &1 == ""))
        |> Enum.join(", ")

      geolocation_data = %{
        latitude: latitude,
        longitude: longitude,
        accuracy: nil,
        address: address
      }

      {:ok, geolocation_data}
    else
      _ -> {:error, :position_not_found}
    end
  end
end
