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

defmodule Edgehog.Geolocation.Providers.GoogleGeocodingTest do
  use Edgehog.DataCase, async: true

  import Tesla.Mock
  alias Edgehog.Geolocation.Location
  alias Edgehog.Geolocation.Position
  alias Edgehog.Geolocation.Providers.GoogleGeocoding

  @moduletag :ported_to_ash

  describe "geocoding" do
    test "reverse_geocode/1 returns an address from coordinates" do
      timestamp = DateTime.now!("Etc/UTC")
      position = %Position{latitude: 40.714224, longitude: -73.961452, timestamp: timestamp}

      response = %{
        "results" => [
          %{
            "formatted_address" => "4 Privet Drive, Little Whinging, Surrey, UK"
          }
        ]
      }

      mock(fn
        %{method: :get, url: "https://maps.googleapis.com/maps/api/geocode/json"} ->
          json(response)
      end)

      assert {:ok, location} = GoogleGeocoding.reverse_geocode(position)

      assert %Location{
               formatted_address: "4 Privet Drive, Little Whinging, Surrey, UK",
               timestamp: ^timestamp
             } = location
    end

    test "reverse_geocode/1 returns error without results from Google" do
      timestamp = DateTime.now!("Etc/UTC")
      position = %Position{latitude: 40.714224, longitude: -73.961452, timestamp: timestamp}

      response = %{
        "garbage" => "error"
      }

      mock(fn
        %{method: :get, url: "https://maps.googleapis.com/maps/api/geocode/json"} ->
          json(response)
      end)

      assert {:error, :location_not_found} == GoogleGeocoding.reverse_geocode(position)
    end
  end
end
