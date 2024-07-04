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

defmodule Edgehog.Geolocation.Providers.GoogleGeocoding do
  @moduledoc false
  @behaviour Edgehog.Geolocation.GeocodingProvider

  use Tesla

  alias Edgehog.Config
  alias Edgehog.Geolocation.Location
  alias Edgehog.Geolocation.Position

  plug Tesla.Middleware.BaseUrl, "https://maps.googleapis.com/maps/api/geocode/json"
  plug Tesla.Middleware.JSON

  @impl Edgehog.Geolocation.GeocodingProvider
  def reverse_geocode(%Position{} = position) do
    %Position{latitude: latitude, longitude: longitude, timestamp: timestamp} = position

    with {:ok, api_key} <- Config.google_geocoding_api_key(),
         query_params = [key: api_key, latlng: "#{latitude},#{longitude}"],
         {:ok, response} <- get("", query: query_params) do
      results = Map.get(response.body, "results", [])

      if Enum.empty?(results) do
        {:error, :location_not_found}
      else
        formatted_address =
          results
          |> List.first()
          |> Map.get("formatted_address")

        location = %Location{
          formatted_address: formatted_address,
          timestamp: timestamp,
          source: """
          Location estimated by reverse geocoding the available position.\
          """
        }

        {:ok, location}
      end
    end
  end
end
