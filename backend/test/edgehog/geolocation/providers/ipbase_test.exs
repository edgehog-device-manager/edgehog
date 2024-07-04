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
  use Edgehog.DataCase, async: true

  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures
  import Tesla.Mock

  alias Edgehog.Astarte.Device.DeviceStatus
  alias Edgehog.Astarte.Device.DeviceStatusMock
  alias Edgehog.Geolocation.Position
  alias Edgehog.Geolocation.Providers.IPBase

  describe "ip_geolocation" do
    setup do
      stub(DeviceStatusMock, :get, fn _client, _device_id ->
        device_status = %DeviceStatus{
          last_connection: ~U[2021-11-15 10:44:57.432516Z],
          last_disconnection: ~U[2021-11-15 10:45:57.432516Z],
          last_seen_ip: "198.51.100.25"
        }

        {:ok, device_status}
      end)

      device = device_fixture(tenant: tenant_fixture())

      {:ok, device: device}
    end

    test "geolocate/1 returns error without input IP address", %{device: device} do
      expect(DeviceStatusMock, :get, fn _appengine_client, _device_id ->
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
        "data" => %{
          "location" => %{
            "latitude" => 45.4019498,
            "longitude" => 11.8706081
          }
        }
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert {:ok, position} = IPBase.geolocate(device)

      assert %Position{
               latitude: 45.4019498,
               longitude: 11.8706081,
               accuracy: nil,
               altitude: nil,
               altitude_accuracy: nil,
               heading: nil,
               speed: nil
             } = position
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
