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

defmodule EdgehogWeb.Schema.Query.DeviceTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase
  use Edgehog.EphemeralImageMockCase

  import Edgehog.AstarteFixtures
  import Edgehog.OSManagementFixtures

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

    test "returns the device if it's present", %{conn: conn, api_path: api_path, realm: realm} do
      %Device{
        id: id,
        name: name,
        device_id: device_id,
        online: online
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "device" => device
               }
             } = json_response(conn, 200)

      assert device["name"] == name
      assert device["deviceId"] == device_id
      assert device["online"] == online
    end

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

    test "returns the storage usage if available", %{conn: conn, api_path: api_path, realm: realm} do
      %Device{
        id: id
      } = device_fixture(realm)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @storage_usage_query, variables: variables)

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

    @ota_operations_query """
    query ($id: id!) {
      device(id: $id) {
        otaOperations {
          id
          status
        }
      }
    }
    """

    test "returns the OTA operations if available", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      device = device_fixture(realm)

      %Device{
        id: id
      } = device

      ota_operation = manual_ota_operation_fixture(device)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @ota_operations_query, variables: variables)

      assert %{
               "data" => %{
                 "device" => %{
                   "otaOperations" => [operation]
                 }
               }
             } = json_response(conn, 200)

      assert {:ok, %{id: decoded_id, type: :ota_operation}} =
               Absinthe.Relay.Node.from_global_id(operation["id"], EdgehogWeb.Schema)

      assert decoded_id == ota_operation.id
      assert operation["status"] == "PENDING"
    end
  end
end
