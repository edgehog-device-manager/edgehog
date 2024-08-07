#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Geolocation.Providers.DeviceGeolocationTest do
  use Edgehog.DataCase, async: true

  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.GeolocationMock
  alias Edgehog.Geolocation.Position
  alias Edgehog.Geolocation.Providers.DeviceGeolocation

  describe "device_geolocation" do
    alias Edgehog.Astarte.Device.Geolocation.SensorPosition

    setup do
      device = device_fixture(tenant: tenant_fixture())

      {:ok, device: device}
    end

    test "geolocate/1 returns error without input SensorPosition list", %{device: device} do
      expect(GeolocationMock, :get, fn _appengine_client, _device_id -> {:ok, []} end)
      assert DeviceGeolocation.geolocate(device) == {:error, :sensor_positions_not_found}
    end

    test "geolocate/1 returns position from SensorPosition list", %{device: device} do
      sensors_positions = [
        %SensorPosition{
          sensor_id: "gps1",
          latitude: 45.4095285,
          longitude: 11.8788231,
          altitude: nil,
          accuracy: 0,
          altitude_accuracy: nil,
          heading: nil,
          speed: nil,
          timestamp: ~U[2021-11-30 10:45:00.575Z]
        }
      ]

      expect(GeolocationMock, :get, fn _appengine_client, _device_id ->
        {:ok, sensors_positions}
      end)

      assert {:ok, position} = DeviceGeolocation.geolocate(device)

      assert %Position{
               latitude: 45.4095285,
               longitude: 11.8788231,
               accuracy: 0,
               altitude: nil,
               altitude_accuracy: nil,
               heading: nil,
               speed: nil,
               timestamp: ~U[2021-11-30 10:45:00.575Z],
               source:
                 "Sensor position published by the device on the io.edgehog.devicemanager.Geolocation Astarte interface."
             } == position
    end

    test "geolocate/1 returns error if fetching from the device fails", %{device: device} do
      expect(GeolocationMock, :get, fn _appengine_client, _device_id ->
        {:error, :some_astarte_error}
      end)

      assert {:error, :sensor_positions_not_found} == DeviceGeolocation.geolocate(device)
    end
  end
end
