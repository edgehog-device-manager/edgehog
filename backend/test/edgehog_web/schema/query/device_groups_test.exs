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

defmodule EdgehogWeb.Schema.Query.DeviceGroupsTest do
  use EdgehogWeb.ConnCase

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  alias Edgehog.Devices
  alias Edgehog.Groups.DeviceGroup

  describe "deviceGroups field" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      {:ok, device_foo} =
        device_fixture(realm)
        |> Devices.update_device(%{tags: ["foo"]})

      {:ok, device_bar} =
        device_fixture(realm, name: "Device Bar", device_id: "eTezXt3hST2bPEw0Inq56A")
        |> Devices.update_device(%{tags: ["bar"]})

      {:ok, realm: realm, device_foo: device_foo, device_bar: device_bar}
    end

    @query """
    query {
      deviceGroups {
        id
        name
        handle
        selector
        devices {
          id
          name
          deviceId
        }
      }
    }
    """
    test "returns empty device groups", %{conn: conn, api_path: api_path} do
      conn = get(conn, api_path, query: @query)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "deviceGroups" => []
               }
             }
    end

    test "returns device groups if they're present", %{
      conn: conn,
      api_path: api_path,
      device_foo: device_foo
    } do
      %DeviceGroup{id: dg_id} =
        device_group_fixture(name: "Foos", handle: "foos", selector: ~s<"foo" in tags>)

      conn = get(conn, api_path, query: @query)

      assert %{
               "data" => %{
                 "deviceGroups" => [device_group]
               }
             } = json_response(conn, 200)

      assert {:ok, %{id: id, type: :device_group}} =
               Absinthe.Relay.Node.from_global_id(device_group["id"], EdgehogWeb.Schema)

      assert id == to_string(dg_id)

      assert device_group["name"] == "Foos"
      assert device_group["handle"] == "foos"
      assert device_group["selector"] == ~s<"foo" in tags>
      assert [device] = device_group["devices"]
      assert device["name"] == device_foo.name
      assert device["deviceId"] == device_foo.device_id

      assert {:ok, %{id: d_id, type: :device}} =
               Absinthe.Relay.Node.from_global_id(device["id"], EdgehogWeb.Schema)

      assert d_id == to_string(device_foo.id)
    end
  end
end
