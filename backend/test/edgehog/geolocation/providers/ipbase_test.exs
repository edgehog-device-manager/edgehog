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

defmodule Edgehog.Geolocation.Providers.IPBaseTest do
  use Edgehog.DataCase
  use Edgehog.AstarteMockCase

  import Edgehog.AstarteFixtures
  import Tesla.Mock
  alias Edgehog.Astarte.Device.DeviceStatus
  alias Edgehog.Geolocation.Position
  alias Edgehog.Geolocation.Providers.IPBase

  describe "ip_geolocation" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)
      device = device_fixture(realm)

      {:ok, cluster: cluster, realm: realm, device: device}
    end

    test "geolocate/1 returns error without input IP address", %{device: device} do
      Edgehog.Astarte.Device.DeviceStatusMock
      |> expect(:get, fn _appengine_client, _device_id ->
        {:ok,
         %DeviceStatus{
           last_connection: nil,
           last_disconnection: nil,
           online: false,
           last_seen_ip: nil
         }}
      end)

      assert IPBase.geolocate(device) == {:error, :position_not_found}
    end

    test "geolocate/1 returns position from IP address", %{device: device} do
      response = %{
        "latitude" => 45.4019498,
        "longitude" => 11.8706081
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert {:ok, position} = IPBase.geolocate(device)
      assert %Position{accuracy: nil, latitude: 45.4019498, longitude: 11.8706081} = position
    end

    test "geolocate/1 returns error without results from IPBase", %{device: device} do
      response = %{
        "garbage" => "error"
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert IPBase.geolocate(device) == {:error, :position_not_found}
    end
  end
end
