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

defmodule EdgehogWeb.Schema.Mutation.UpdateDeviceGroupTest do
  use EdgehogWeb.ConnCase

  import Edgehog.GroupsFixtures

  alias Edgehog.Groups.DeviceGroup

  describe "updateDeviceGroup field" do
    setup do
      {:ok, device_group: device_group_fixture()}
    end

    @query """
    mutation UpdateDeviceGroup($input: UpdateDeviceGroupInput!) {
      updateDeviceGroup(input: $input) {
        deviceGroup {
          id
          name
          handle
          selector
        }
      }
    }
    """
    test "updates device group with valid data", %{
      conn: conn,
      api_path: api_path,
      device_group: device_group
    } do
      name = "Updated"
      handle = "updated"
      selector = ~s<"updated" in tags>

      id = Absinthe.Relay.Node.to_global_id(:device_group, device_group.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          device_group_id: id,
          name: name,
          handle: handle,
          selector: selector
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "updateDeviceGroup" => %{
                   "deviceGroup" => %{
                     "id" => ^id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "selector" => ^selector
                   }
                 }
               }
             } = assert(json_response(conn, 200))
    end

    test "updates device group with partial data", %{
      conn: conn,
      api_path: api_path,
      device_group: device_group
    } do
      %DeviceGroup{name: initial_name, handle: initial_handle} = device_group

      selector = ~s<"updated" in tags>

      id = Absinthe.Relay.Node.to_global_id(:device_group, device_group.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          device_group_id: id,
          selector: selector
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "updateDeviceGroup" => %{
                   "deviceGroup" => %{
                     "id" => ^id,
                     "name" => ^initial_name,
                     "handle" => ^initial_handle,
                     "selector" => ^selector
                   }
                 }
               }
             } = assert(json_response(conn, 200))
    end

    test "fails with invalid data", %{conn: conn, api_path: api_path, device_group: device_group} do
      id = Absinthe.Relay.Node.to_global_id(:device_group, device_group.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          device_group_id: id,
          name: nil,
          handle: nil,
          selector: "invalid"
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => _} = assert(json_response(conn, 200))
    end

    test "fails with non existing id", %{conn: conn, api_path: api_path} do
      name = "Updated"
      handle = "updated"
      selector = ~s<"updated" in tags>

      id = Absinthe.Relay.Node.to_global_id(:device_group, 1_234_539, EdgehogWeb.Schema)

      variables = %{
        input: %{
          device_group_id: id,
          name: name,
          handle: handle,
          selector: selector
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => [%{"code" => "not_found", "status_code" => 404}]} =
               assert(json_response(conn, 200))
    end
  end
end
