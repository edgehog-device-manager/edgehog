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

defmodule EdgehogWeb.Schema.Mutation.CreateHardwareTypeTest do
  use EdgehogWeb.ConnCase, async: true

  alias Edgehog.Devices
  alias Edgehog.Devices.HardwareType

  describe "createHardwareType field" do
    @query """
    mutation CreateHardwareType($input: CreateHardwareTypeInput!) {
      createHardwareType(input: $input) {
        hardwareType {
          id
          name
          handle
          partNumbers
        }
      }
    }
    """
    test "creates hardware type with valid data", %{conn: conn, api_path: api_path} do
      name = "Foobar"
      handle = "foobar"
      part_number = "12345/X"

      variables = %{
        input: %{
          name: name,
          handle: handle,
          part_numbers: [part_number]
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "createHardwareType" => %{
                   "hardwareType" => %{
                     "id" => id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "partNumbers" => [^part_number]
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      {:ok, %{type: :hardware_type, id: db_id}} =
        Absinthe.Relay.Node.from_global_id(id, EdgehogWeb.Schema)

      assert {:ok, %HardwareType{name: ^name, handle: ^handle}} =
               Devices.fetch_hardware_type(db_id)
    end

    test "fails with invalid data", %{conn: conn, api_path: api_path} do
      variables = %{
        input: %{
          name: nil,
          handle: nil,
          part_numbers: []
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => _} = assert(json_response(conn, 200))
    end
  end
end
