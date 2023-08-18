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
  use EdgehogWeb.ConnCase, async: true
  use Edgehog.AstarteMockCase
  use Edgehog.EphemeralImageMockCase

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.OSManagementFixtures

  alias Edgehog.Devices
  alias Edgehog.Devices.Device
  alias Edgehog.Groups.DeviceGroup

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

    @query """
    query ($id: ID!) {
      device(id: $id) {
        tags
      }
    }
    """

    test "returns the tags", %{conn: conn, api_path: api_path, realm: realm} do
      {:ok, %Device{id: id}} =
        device_fixture(realm)
        |> Devices.update_device(%{tags: ["foo", "bar"]})

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "device" => device
               }
             } = json_response(conn, 200)

      assert device["tags"] == ["foo", "bar"]
    end

    @custom_attributes_query """
    query ($id: ID!) {
      device(id: $id) {
        customAttributes {
          namespace
          key
          type
          value
        }
      }
    }
    """

    test "returns custom attributes for all types", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      custom_attributes = [
        %{
          namespace: :custom,
          key: "double",
          typed_value: %{
            type: :double,
            value: 42.0
          }
        },
        %{
          namespace: :custom,
          key: "integer",
          typed_value: %{
            type: :integer,
            value: 300
          }
        },
        %{
          namespace: :custom,
          key: "boolean",
          typed_value: %{
            type: :boolean,
            value: true
          }
        },
        %{
          namespace: :custom,
          key: "longinteger",
          typed_value: %{
            type: :longinteger,
            value: "1234567890"
          }
        },
        %{
          namespace: :custom,
          key: "string",
          typed_value: %{
            type: :string,
            value: "foobar"
          }
        },
        %{
          namespace: :custom,
          key: "binaryblob",
          typed_value: %{
            type: :binaryblob,
            value: "ZWRnZWhvZw=="
          }
        },
        %{
          namespace: :custom,
          key: "datetime",
          typed_value: %{
            type: :datetime,
            value: "2022-06-10T16:27:41.235243Z"
          }
        }
      ]

      {:ok, %Device{id: id}} =
        device_fixture(realm)
        |> Devices.update_device(%{custom_attributes: custom_attributes})

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @custom_attributes_query, variables: variables)

      assert %{
               "data" => %{
                 "device" => %{
                   "customAttributes" => custom_attributes
                 }
               }
             } = json_response(conn, 200)

      assert %{"key" => "double", "namespace" => "CUSTOM", "type" => "DOUBLE", "value" => 42.0} in custom_attributes

      assert %{
               "key" => "integer",
               "namespace" => "CUSTOM",
               "type" => "INTEGER",
               "value" => 300
             } in custom_attributes

      assert %{
               "key" => "boolean",
               "namespace" => "CUSTOM",
               "type" => "BOOLEAN",
               "value" => true
             } in custom_attributes

      assert %{
               "key" => "longinteger",
               "namespace" => "CUSTOM",
               "type" => "LONGINTEGER",
               "value" => "1234567890"
             } in custom_attributes

      assert %{
               "key" => "string",
               "namespace" => "CUSTOM",
               "type" => "STRING",
               "value" => "foobar"
             } in custom_attributes

      assert %{
               "key" => "binaryblob",
               "namespace" => "CUSTOM",
               "type" => "BINARYBLOB",
               "value" => "ZWRnZWhvZw=="
             } in custom_attributes

      assert %{
               "key" => "datetime",
               "namespace" => "CUSTOM",
               "type" => "DATETIME",
               "value" => "2022-06-10T16:27:41.235243Z"
             } in custom_attributes
    end

    @groups_query """
    query ($id: ID!) {
      device(id: $id) {
        deviceGroups {
          id
          handle
        }
      }
    }
    """

    test "returns the device groups", %{conn: conn, api_path: api_path, realm: realm} do
      %DeviceGroup{id: foos_id} =
        device_group_fixture(name: "Foos", handle: "foos", selector: ~s<"foo" in tags>)

      foos_global_id = Absinthe.Relay.Node.to_global_id(:device_group, foos_id, EdgehogWeb.Schema)

      %DeviceGroup{id: bars_id} =
        device_group_fixture(name: "Bars", handle: "bars", selector: ~s<"bar" in tags>)

      bars_global_id = Absinthe.Relay.Node.to_global_id(:device_group, bars_id, EdgehogWeb.Schema)

      {:ok, %Device{id: id}} =
        device_fixture(realm)
        |> Devices.update_device(%{tags: ["foo", "bar"]})

      variables = %{id: Absinthe.Relay.Node.to_global_id(:device, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @groups_query, variables: variables)

      assert %{
               "data" => %{
                 "device" => %{
                   "deviceGroups" => device_groups
                 }
               }
             } = json_response(conn, 200)

      assert length(device_groups) == 2
      assert %{"handle" => "foos", "id" => foos_global_id} in device_groups
      assert %{"handle" => "bars", "id" => bars_global_id} in device_groups
    end
  end
end
