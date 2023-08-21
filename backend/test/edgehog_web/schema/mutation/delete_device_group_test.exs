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

defmodule EdgehogWeb.Schema.Mutation.DeleteDeviceGroupTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.GroupsFixtures

  alias Edgehog.Groups
  alias Edgehog.Groups.DeviceGroup

  describe "deleteDeviceGroup field" do
    setup do
      {:ok, device_group: device_group_fixture()}
    end

    @query """
    mutation DeleteDeviceGroup($input: DeleteDeviceGroupInput!) {
      deleteDeviceGroup(input: $input) {
        deviceGroup {
          id
          name
          handle
          selector
        }
      }
    }
    """
    test "deletes device group", %{
      conn: conn,
      api_path: api_path,
      device_group: device_group
    } do
      %DeviceGroup{name: name, handle: handle, selector: selector} = device_group
      id = Absinthe.Relay.Node.to_global_id(:device_group, device_group.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          device_group_id: id
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "deleteDeviceGroup" => %{
                   "deviceGroup" => %{
                     "id" => ^id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "selector" => ^selector
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      assert {:error, :not_found} = Groups.fetch_device_group(device_group.id)
    end

    test "fails with non existing id", %{conn: conn, api_path: api_path} do
      id = Absinthe.Relay.Node.to_global_id(:device_group, 1_234_539, EdgehogWeb.Schema)

      variables = %{
        input: %{
          device_group_id: id
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => [%{"code" => "not_found", "status_code" => 404}]} =
               assert(json_response(conn, 200))
    end
  end
end
