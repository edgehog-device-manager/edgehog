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

defmodule EdgehogWeb.Schema.Mutation.CreateDeviceGroupTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Devices
  alias Edgehog.Groups
  alias Edgehog.Groups.DeviceGroup

  describe "createDeviceGroup field" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      {:ok, device_answer} =
        device_fixture(realm)
        |> Devices.update_device(%{
          custom_attributes: [
            %{
              namespace: "custom",
              key: "answer",
              typed_value: %{type: :integer, value: 42}
            }
          ]
        })

      {:ok, device_no_answer} =
        device_fixture(realm, name: "No Answer", device_id: "eTezXt3hST2bPEw0Inq56A")
        |> Devices.update_device(%{
          custom_attributes: [
            %{
              namespace: "custom",
              key: "answer",
              typed_value: %{type: :integer, value: 0}
            }
          ]
        })

      {:ok, realm: realm, device_answer: device_answer, device_no_answer: device_no_answer}
    end

    @query """
    mutation CreateDeviceGroup($input: CreateDeviceGroupInput!) {
      createDeviceGroup(input: $input) {
        deviceGroup {
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
    }
    """
    test "creates device group with valid data", %{
      conn: conn,
      api_path: api_path,
      device_answer: device_answer
    } do
      name = "With Answer"
      handle = "with-answer"
      selector = ~s<attributes["custom:answer"] == 42>

      variables = %{
        input: %{
          name: name,
          handle: handle,
          selector: selector
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "createDeviceGroup" => %{
                   "deviceGroup" => %{
                     "id" => id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "devices" => [device]
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      {:ok, %{type: :device_group, id: db_id}} =
        Absinthe.Relay.Node.from_global_id(id, EdgehogWeb.Schema)

      assert {:ok, %DeviceGroup{name: ^name, handle: ^handle}} = Groups.fetch_device_group(db_id)

      assert device["name"] == device_answer.name
      assert device["deviceId"] == device_answer.device_id

      assert {:ok, %{id: d_id, type: :device}} =
               Absinthe.Relay.Node.from_global_id(device["id"], EdgehogWeb.Schema)

      assert d_id == to_string(device_answer.id)
    end

    test "fails with invalid data", %{conn: conn, api_path: api_path} do
      variables = %{
        input: %{
          name: nil,
          handle: nil,
          selector: "invalid"
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => _} = assert(json_response(conn, 200))
    end
  end
end
