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

defmodule Edgehog.Astarte.Device.StorageUsageTest do
  use Edgehog.DataCase, async: true

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.StorageUsage
  alias Edgehog.Astarte.Device.StorageUsage.StorageUnit

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  @moduletag :ported_to_ash

  describe "storage_usage" do
    import Tesla.Mock

    setup do
      tenant = tenant_fixture()
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
      device = device_fixture(realm_id: realm.id, tenant: tenant)

      {:ok, appengine_client} =
        AppEngine.new(cluster.base_api_url, realm.name, private_key: realm.private_key)

      {:ok, cluster: cluster, realm: realm, device: device, appengine_client: appengine_client}
    end

    test "get/2 correctly parses storage usage data with a single path", %{
      device: device,
      appengine_client: appengine_client
    } do
      response = %{
        "data" => %{
          "nvs1" => [
            %{
              "freeBytes" => "7000",
              "timestamp" => "2021-11-30T10:45:00.575Z",
              "totalBytes" => "16128"
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
               %StorageUnit{free_bytes: 7000, label: "nvs1", total_bytes: 16_128}
             ]
    end

    test "get/2 correctly parses storage usage data with multiple paths", %{
      device: device,
      appengine_client: appengine_client
    } do
      response = %{
        "data" => %{
          "nvs1" => %{
            "freeBytes" => "7000",
            "timestamp" => "2021-11-30T10:45:00.575Z",
            "totalBytes" => "16128"
          },
          "nvs2" => %{
            "freeBytes" => "5000",
            "timestamp" => "2021-11-30T10:41:48.575Z",
            "totalBytes" => "8064"
          }
        }
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert {:ok, storage_units} = StorageUsage.get(appengine_client, device.device_id)

      assert storage_units == [
               %StorageUnit{free_bytes: 7000, label: "nvs1", total_bytes: 16_128},
               %StorageUnit{free_bytes: 5000, label: "nvs2", total_bytes: 8064}
             ]
    end
  end
end
