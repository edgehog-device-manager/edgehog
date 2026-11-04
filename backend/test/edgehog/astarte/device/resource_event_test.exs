#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.ResourceEventTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures
  import Tesla.Mock

  alias Astarte.Client.APIError
  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.ResourceEvent

  describe "get/5" do
    setup do
      tenant = tenant_fixture()
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
      device = device_fixture(realm_id: realm.id, tenant: tenant)

      {:ok, appengine_client} =
        AppEngine.new(cluster.base_api_url, realm.name, private_key: realm.private_key)

      {:ok, cluster: cluster, realm: realm, device: device, appengine_client: appengine_client}
    end

    test "correctly queries and parses resource event data", %{
      device: device,
      appengine_client: appengine_client
    } do
      interface = "io.edgehog.devicemanager.apps.ContainerEvent"
      resource_id = Ash.UUID.generate()

      response = %{
        "data" => [
          %{
            "status" => "Create",
            "message" => "Container created",
            "addInfo" => ["image=nginx:latest"],
            "timestamp" => "2026-11-04T10:15:30.123456Z"
          },
          %{
            "status" => "ExecCreate",
            "timestamp" => "2026-11-04T10:16:00.000000Z"
          }
        ]
      }

      expected_url_suffix =
        "/devices/#{device.device_id}/interfaces/#{interface}/#{resource_id}"

      mock(fn
        %{method: :get, url: api_url, query: []} ->
          assert String.ends_with?(api_url, expected_url_suffix)
          json(response)
      end)

      assert {:ok, events} =
               ResourceEvent.get(appengine_client, device.device_id, interface, resource_id)

      assert events == [
               %ResourceEvent{
                 status: "Create",
                 message: "Container created",
                 add_info: ["image=nginx:latest"],
                 timestamp: ~U[2026-11-04 10:15:30.123456Z]
               },
               %ResourceEvent{
                 status: "ExecCreate",
                 message: "",
                 add_info: [],
                 timestamp: ~U[2026-11-04 10:16:00.000000Z]
               }
             ]
    end

    test "returns empty list when Astarte returns empty map or empty list", %{
      device: device,
      appengine_client: appengine_client
    } do
      interface = "io.edgehog.devicemanager.apps.VolumeEvent"
      resource_id = Ash.UUID.generate()

      mock(fn
        %{method: :get, query: [limit: 50]} ->
          json(%{"data" => %{}})
      end)

      assert {:ok, []} =
               ResourceEvent.get(
                 appengine_client,
                 device.device_id,
                 interface,
                 resource_id,
                 limit: 50
               )
    end

    test "propagates Astarte API errors", %{
      device: device,
      appengine_client: appengine_client
    } do
      interface = "io.edgehog.devicemanager.apps.ImageEvent"
      resource_id = Ash.UUID.generate()

      mock(fn
        %{method: :get} ->
          json(%{"errors" => %{"detail" => "Forbidden"}}, status: 403)
      end)

      assert {:error, %APIError{status: 403}} =
               ResourceEvent.get(appengine_client, device.device_id, interface, resource_id)
    end
  end
end
