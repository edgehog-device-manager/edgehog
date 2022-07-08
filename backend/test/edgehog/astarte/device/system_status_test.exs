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

defmodule Edgehog.Astarte.Device.SystemStatusTest do
  use Edgehog.DataCase

  alias Edgehog.Astarte.Device.SystemStatus
  alias Astarte.Client.AppEngine

  describe "system_status" do
    import Edgehog.AstarteFixtures
    import Tesla.Mock

    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)
      device = astarte_device_fixture(realm)

      {:ok, appengine_client} =
        AppEngine.new(cluster.base_api_url, realm.name, private_key: realm.private_key)

      {:ok, cluster: cluster, realm: realm, device: device, appengine_client: appengine_client}
    end

    test "get/2 correctly parses system status data", %{
      device: device,
      appengine_client: appengine_client
    } do
      response = %{
        "data" => %{
          "systemStatus" => [
            %{
              "availMemoryBytes" => "166772",
              "bootId" => "779f8022-21a0-4c3d-8f37-b1cf2424f111",
              "taskCount" => 32,
              "timestamp" => "2021-11-11T10:44:42.942Z",
              "uptimeMillis" => "5621"
            }
          ]
        }
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert {:ok, system_status} = SystemStatus.get(appengine_client, device.device_id)

      assert system_status == %SystemStatus{
               boot_id: "779f8022-21a0-4c3d-8f37-b1cf2424f111",
               memory_free_bytes: 166_772,
               task_count: 32,
               uptime_milliseconds: 5621,
               timestamp: ~U[2021-11-11T10:44:42.942Z]
             }
    end
  end
end
