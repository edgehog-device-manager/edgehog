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

defmodule Edgehog.Geolocation.Providers.IPBase do
  @behaviour Edgehog.Geolocation.GeolocationProvider

  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device
  alias Edgehog.Config
  alias Edgehog.Geolocation.Position
  alias Edgehog.Repo

  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://api.ipbase.com/v2/info"
  plug Tesla.Middleware.JSON

  @impl Edgehog.Geolocation.GeolocationProvider
  def geolocate(%Device{} = device) do
    device = Repo.preload(device, :realm)

    with {:ok, device_status} <- Astarte.get_device_status(device.realm, device.device_id),
         {:ok, coordinates} <- geolocate_ip(device_status.last_seen_ip) do
      device_last_seen =
        [device_status.last_connection, device_status.last_disconnection]
        |> Enum.reject(&is_nil/1)
        |> Enum.sort({:desc, DateTime})
        |> List.first()

      timestamp = device_last_seen || DateTime.utc_now()

      position = %Position{
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        accuracy: coordinates.accuracy,
        timestamp: timestamp
      }

      {:ok, position}
    end
  end

  defp geolocate_ip(nil) do
    {:error, :position_not_found}
  end

  defp geolocate_ip(ip_address) do
    with {:ok, api_key} <- Config.ipbase_api_key(),
         {:ok, %{body: body}} <- get("", query: [apikey: api_key, ip: ip_address]),
         {:ok, location} <- parse_response_body(body) do
      {:ok, location}
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

      location = %{
        latitude: latitude,
        longitude: longitude,
        accuracy: nil,
        address: address
      }

      {:ok, location}
    else
      _ -> {:error, :position_not_found}
    end
  end
end
