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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Astarte.Device.BatteryStatusTest do
  use Edgehog.DataCase

  alias Edgehog.Astarte.Device.BatteryStatus
  alias Edgehog.Astarte.Device.BatteryStatus.BatterySlot
  alias Astarte.Client.AppEngine

  describe "battery_status" do
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

    test "get/2 correctly parses battery status data", %{
      device: device,
      appengine_client: appengine_client
    } do
      response = %{
        "data" => %{
          "slot1" => [
            %{
              "levelAbsoluteError" => 0.1,
              "levelPercentage" => 80.1,
              "status" => "Charging",
              "timestamp" => "2021-11-30T12:08:57.827Z"
            }
          ],
          "slot2" => [
            %{
              "levelAbsoluteError" => 100.0,
              "levelPercentage" => 70.0,
              "status" => "EitherIdleOrCharging",
              "timestamp" => "2021-11-30T12:08:57.827Z"
            }
          ]
        }
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert {:ok, battery_slots} = BatteryStatus.get(appengine_client, device.device_id)

      assert battery_slots == [
               %BatterySlot{
                 slot: "slot1",
                 level_percentage: 80.1,
                 level_absolute_error: 0.1,
                 status: "Charging"
               },
               %BatterySlot{
                 slot: "slot2",
                 level_percentage: 70.0,
                 level_absolute_error: 100.0,
                 status: "EitherIdleOrCharging"
               }
             ]
    end
  end
end
