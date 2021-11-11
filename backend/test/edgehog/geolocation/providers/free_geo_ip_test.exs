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

defmodule Edgehog.Geolocation.Providers.FreeGeoIpTest do
  use Edgehog.DataCase

  import Tesla.Mock
  alias Edgehog.Geolocation.Providers.FreeGeoIp

  describe "ip_geolocation" do
    test "geolocate/1 returns error without input IP address" do
      assert FreeGeoIp.geolocate(nil) == {:error, :coordinates_not_found}
    end

    test "geolocate/1 returns coordinates from IP address" do
      ip_address = "198.51.100.25"

      response = %{
        "latitude" => 45.4019498,
        "longitude" => 11.8706081
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert {:ok, coordinates} = FreeGeoIp.geolocate(ip_address)
      assert %{accuracy: nil, latitude: 45.4019498, longitude: 11.8706081} = coordinates
    end

    test "geolocate/1 returns error without results from FreeGeoIp" do
      ip_address = "198.51.100.25"

      response = %{
        "garbage" => "error"
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert FreeGeoIp.geolocate(ip_address) == {:error, :coordinates_not_found}
    end
  end
end
