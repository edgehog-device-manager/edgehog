#
# This file is part of Edgehog.
#
# Copyright 2021 - 2025 SECO Mind Srl
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
  @moduledoc false
  @behaviour Edgehog.Geolocation.GeolocationProvider

  alias Edgehog.Config
  alias Edgehog.Devices.Device
  alias Edgehog.EdgehogTeslaClient
  alias Edgehog.Geolocation.Position

  @device_status_attributes [:last_connection, :last_disconnection, :last_seen_ip]

  @impl Edgehog.Geolocation.GeolocationProvider
  def geolocate(%Device{} = device) do
    with {:ok, device_status} <- fetch_device_status(device) do
      %{
        last_seen_ip: last_seen_ip,
        last_connection: last_connection,
        last_disconnection: last_disconnection
      } = device_status

      last_seen_timestamp =
        [last_connection, last_disconnection]
        |> Enum.reject(&is_nil/1)
        |> Enum.sort({:desc, DateTime})
        |> List.first(DateTime.utc_now())

      geolocate_ip(last_seen_ip, last_seen_timestamp)
    end
  end

  defp fetch_device_status(%Device{} = device) do
    if uninitialized_device_status?(device) do
      with {:ok, device_data} <- Ash.load(device, :device_status),
           :ok <- validate_device_status_exists(device_data.device_status) do
        {:ok, device_data.device_status}
      end
    else
      {:ok,
       %{
         last_seen_ip: device.last_seen_ip,
         last_connection: device.last_connection,
         last_disconnection: device.last_disconnection
       }}
    end
  end

  defp uninitialized_device_status?(device) do
    Enum.any?(@device_status_attributes, &(Map.get(device, &1) == nil))
  end

  defp validate_device_status_exists(nil), do: {:error, :device_status_not_found}
  defp validate_device_status_exists(_), do: :ok

  defp geolocate_ip(nil, _timestamp) do
    {:error, :position_not_found}
  end

  defp geolocate_ip(ip_address, timestamp) do
    with {:ok, api_key} <- Config.ipbase_api_key(),
         {:ok, %{body: body}} <-
           EdgehogTeslaClient.get("https://api.ipbase.com/v2/info",
             query: [apikey: api_key, ip: ip_address]
           ),
         {:ok, geolocation_data} <- parse_response_body(body) do
      position = %Position{
        latitude: geolocation_data.latitude,
        longitude: geolocation_data.longitude,
        accuracy: geolocation_data.accuracy,
        altitude: nil,
        altitude_accuracy: nil,
        heading: nil,
        speed: nil,
        timestamp: timestamp,
        source: """
        GPS position estimated from the last known IP address of the device.\
        """
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
