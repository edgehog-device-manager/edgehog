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

defmodule EdgehogWeb.Schema.Query.DeviceGroupTest do
  use EdgehogWeb.ConnCase

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Edgehog.Devices
  alias Edgehog.Groups.DeviceGroup

  describe "deviceGroup field" do
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
    query ($id: ID!) {
      deviceGroup(id: $id) {
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
    test "returns not found for unexisting device group", %{conn: conn, api_path: api_path} do
      variables = %{
        id: Absinthe.Relay.Node.to_global_id(:device_group, 303_040, EdgehogWeb.Schema)
      }

      conn = get(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "deviceGroup" => nil
               },
               "errors" => [
                 %{"path" => ["deviceGroup"], "status_code" => 404, "code" => "not_found"}
               ]
             } = json_response(conn, 200)
    end

    test "returns device group if it's present", %{
      conn: conn,
      api_path: api_path,
      device_foo: device_foo
    } do
      %DeviceGroup{id: dg_id} =
        device_group_fixture(name: "Foos", handle: "foos", selector: ~s<"foo" in tags>)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device_group, dg_id, EdgehogWeb.Schema)}
      conn = get(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "deviceGroup" => device_group
               }
             } = json_response(conn, 200)

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

    @update_channel_query """
    query ($id: ID!) {
      deviceGroup(id: $id) {
        updateChannel {
          id
          handle
          name
        }
      }
    }
    """
    test "allows querying updateChannel if present", %{conn: conn, api_path: api_path} do
      %DeviceGroup{id: dg_id} = device_group_fixture()
      update_channel = update_channel_fixture(target_group_ids: [dg_id])

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device_group, dg_id, EdgehogWeb.Schema)}
      conn = get(conn, api_path, query: @update_channel_query, variables: variables)

      assert %{
               "data" => %{
                 "deviceGroup" => device_group
               }
             } = json_response(conn, 200)

      assert device_group["updateChannel"]["id"] ==
               Absinthe.Relay.Node.to_global_id(
                 :update_channel,
                 update_channel.id,
                 EdgehogWeb.Schema
               )

      assert device_group["updateChannel"]["handle"] == update_channel.handle
      assert device_group["updateChannel"]["name"] == update_channel.name
    end
  end
end
