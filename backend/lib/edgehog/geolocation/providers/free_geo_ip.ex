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

defmodule Edgehog.Geolocation.Providers.FreeGeoIp do
  @behaviour Edgehog.Geolocation.GeolocationProvider

  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device
  alias Edgehog.Geolocation.Position
  alias Edgehog.Repo

  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://freegeoip.app/json"
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
    config = Application.fetch_env!(:edgehog, Edgehog.Geolocation.Providers.FreeGeoIp)
    api_key = Keyword.fetch!(config, :api_key)

    query_params = [apikey: api_key]

    with {:ok, %{body: body}} <- get("/#{ip_address}", query: query_params),
         {:coords, %{"latitude" => latitude, "longitude" => longitude}}
         when is_number(latitude) and is_number(longitude) <- {:coords, body} do
      address =
        [
          body["city"],
          body["zip_code"],
          body["region_name"],
          body["country_name"]
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join(", ")

      location = %{
        latitude: latitude,
        longitude: longitude,
        accuracy: nil,
        address: address
      }

      {:ok, location}
    else
      {:coords, _} ->
        {:error, :position_not_found}
    end
  end
end
