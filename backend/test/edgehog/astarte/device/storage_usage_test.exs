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

defmodule Edgehog.Astarte.Device.StorageUsageTest do
  use Edgehog.DataCase

  alias Edgehog.Astarte.Device.StorageUsage
  alias Edgehog.Astarte.Device.StorageUsage.StorageUnit
  alias Astarte.Client.AppEngine

  describe "storage_usage" do
    import Edgehog.AstarteFixtures
    import Tesla.Mock

    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)
      device = device_fixture(realm)
      {:ok, appengine_client} = AppEngine.new(cluster.base_api_url, realm.name, realm.private_key)

      {:ok, cluster: cluster, realm: realm, device: device, appengine_client: appengine_client}
    end

    test "get/2 correctly parses storage usage data", %{
      device: device,
      appengine_client: appengine_client
    } do
      response = %{
        "data" => %{
          "nvs1" => [
            %{
              "freeBytes" => "7000",
              "timestamp" => "2021-11-30T10:41:48.575Z",
              "totalBytes" => "16128"
            },
            %{
              "freeBytes" => "8960",
              "timestamp" => "2021-11-29T10:43:17.428Z",
              "totalBytes" => "16128"
            }
          ],
          "nvs2" => [
            %{
              "freeBytes" => "5000",
              "timestamp" => "2021-11-30T10:41:48.575Z",
              "totalBytes" => "8064"
            }
          ]
        }
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert {:ok, storage_units} = StorageUsage.get(appengine_client, device.device_id)

      assert storage_units == [
               %StorageUnit{free_bytes: 7000, label: "nvs1", total_bytes: 16128},
               %StorageUnit{free_bytes: 5000, label: "nvs2", total_bytes: 8064}
             ]
    end
  end
end
