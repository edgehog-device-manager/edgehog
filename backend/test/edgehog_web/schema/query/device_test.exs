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

defmodule EdgehogWeb.Schema.Query.DeviceTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase

  import Edgehog.AstarteFixtures

  alias Edgehog.Astarte.Device

  describe "device query" do
    setup do
      cluster = cluster_fixture()

      {:ok, realm: realm_fixture(cluster)}
    end

    @query """
    query ($id: ID!) {
      device(id: $id) {
        name
        deviceId
        online
      }
    }
    """

    @storage_usage_query """
    query ($id: ID!) {
      device(id: $id) {
        storageUsage {
          label
          totalBytes
          freeBytes
        }
      }
    }
    """

    test "returns the device if it's present", %{conn: conn, realm: realm} do
      %Device{
        id: id,
        name: name,
        device_id: device_id,
        online: online
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, "/api", query: @query, variables: variables)

      assert %{
               "data" => %{
                 "device" => device
               }
             } = json_response(conn, 200)

      assert device["name"] == name
      assert device["deviceId"] == device_id
      assert device["online"] == online
    end

    test "returns the storage usage if available", %{conn: conn, realm: realm} do
      %Device{
        id: id
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, "/api", query: @storage_usage_query, variables: variables)

      assert %{
               "data" => %{
                 "device" => %{
                   "storageUsage" => [storage]
                 }
               }
             } = json_response(conn, 200)

      assert storage["label"] == "Disk 0"
      assert storage["totalBytes"] == 348_360_704
      assert storage["freeBytes"] == 281_360_704
    end
  end
end
