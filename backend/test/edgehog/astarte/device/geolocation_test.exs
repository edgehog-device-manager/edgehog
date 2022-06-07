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

defmodule Edgehog.Astarte.Device.GeolocationTest do
  use Edgehog.DataCase

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.Geolocation
  alias Edgehog.Astarte.Device.Geolocation.SensorPosition

  describe "geolocation" do
    import Edgehog.AstarteFixtures
    import Tesla.Mock

    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)
      device = device_fixture(realm)

      {:ok, appengine_client} =
        AppEngine.new(cluster.base_api_url, realm.name, private_key: realm.private_key)

      {:ok, cluster: cluster, realm: realm, device: device, appengine_client: appengine_client}
    end

    test "get/2 correctly parses geolocation data with a single path", %{
      device: device,
      appengine_client: appengine_client
    } do
      response = %{
        "data" => %{
          "gps1" => [
            %{
              "latitude" => 45.4095285,
              "longitude" => 11.8788231,
              "altitude" => nil,
              "accuracy" => 0,
              "altitudeAccuracy" => nil,
              "heading" => nil,
              "speed" => nil,
              "timestamp" => "2021-11-30T10:45:00.575Z"
            }
          ]
        }
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert {:ok, sensors_positions} = Geolocation.get(appengine_client, device.device_id)

      assert sensors_positions == [
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
    end

    test "get/2 correctly parses geolocation data with multiple paths", %{
      device: device,
      appengine_client: appengine_client
    } do
      response = %{
        "data" => %{
          "gps1" => %{
            "latitude" => 45.4095285,
            "longitude" => 11.8788231,
            "altitude" => nil,
            "accuracy" => 0,
            "altitudeAccuracy" => nil,
            "heading" => nil,
            "speed" => nil,
            "timestamp" => "2021-11-30T10:45:00.575Z"
          },
          "gps2" => %{
            "latitude" => 45.4,
            "longitude" => 11.9,
            "altitude" => nil,
            "accuracy" => 50,
            "altitudeAccuracy" => nil,
            "heading" => nil,
            "speed" => nil,
            "timestamp" => "2021-11-30T10:45:00.575Z"
          }
        }
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert {:ok, sensors_positions} = Geolocation.get(appengine_client, device.device_id)

      assert sensors_positions == [
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
               },
               %SensorPosition{
                 sensor_id: "gps2",
                 latitude: 45.4,
                 longitude: 11.9,
                 altitude: nil,
                 accuracy: 50,
                 altitude_accuracy: nil,
                 heading: nil,
                 speed: nil,
                 timestamp: ~U[2021-11-30 10:45:00.575Z]
               }
             ]
    end
  end
end
