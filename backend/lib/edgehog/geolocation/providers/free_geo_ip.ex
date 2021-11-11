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

defmodule Edgehog.Geolocation.Providers.FreeGeoIp do
  @behaviour Edgehog.Geolocation.IPGeolocationProvider

  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://freegeoip.app/json"
  plug Tesla.Middleware.JSON

  @impl Edgehog.Geolocation.IPGeolocationProvider
  def geolocate(nil = _ip_address) do
    {:error, :coordinates_not_found}
  end

  @impl Edgehog.Geolocation.IPGeolocationProvider
  def geolocate(ip_address) do
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
        {:error, :coordinates_not_found}
    end
  end
end
