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

defmodule Edgehog.Geolocation.Providers.GoogleGeocodingTest do
  use Edgehog.DataCase

  import Tesla.Mock
  alias Edgehog.Geolocation.Providers.GoogleGeocoding

  describe "geocoding" do
    test "reverse_geocode/1 returns an address from coordinates" do
      coords = %{latitude: 40.714224, longitude: -73.961452}

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

      assert {:ok, address} = GoogleGeocoding.reverse_geocode(coords)
      assert address == "4 Privet Drive, Little Whinging, Surrey, UK"
    end

    test "reverse_geocode/1 returns error without results from Google" do
      coords = %{latitude: 40.714224, longitude: -73.961452}

      response = %{
        "garbage" => "error"
      }

      mock(fn
        %{method: :get, url: "https://maps.googleapis.com/maps/api/geocode/json"} ->
          json(response)
      end)

      assert {:error, :address_not_found} == GoogleGeocoding.reverse_geocode(coords)
    end
  end
end
