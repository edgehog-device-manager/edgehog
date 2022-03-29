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

defmodule EdgehogWeb.Schema.Mutation.DeleteHardwareTypeTest do
  use EdgehogWeb.ConnCase

  alias Edgehog.Devices.HardwareType

  describe "deleteHardwareType field" do
    import Edgehog.DevicesFixtures

    @query """
    mutation DeleteHardwareType($input: DeleteHardwareTypeInput!) {
      deleteHardwareType(input: $input) {
        hardwareType {
          id
          handle
          name
          partNumbers
        }
      }
    }
    """

    test "deletes hardware type", %{conn: conn, api_path: api_path} do
      name = "Foobaz"
      handle = "foobaz"
      part_number = "HT-1234"

      %HardwareType{id: id} =
        hardware_type_fixture(
          name: name,
          handle: handle,
          part_numbers: [part_number]
        )

      id = Absinthe.Relay.Node.to_global_id(:hardware_type, id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          hardware_type_id: id
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "deleteHardwareType" => %{
                   "hardwareType" => %{
                     "id" => ^id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "partNumbers" => [^part_number]
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "fails with non-existing id", %{conn: conn, api_path: api_path} do
      id = Absinthe.Relay.Node.to_global_id(:hardware_type, 10_000_000, EdgehogWeb.Schema)

      variables = %{
        input: %{
          hardware_type_id: id
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => [%{"code" => "not_found", "status_code" => 404}]} =
               json_response(conn, 200)
    end
  end
end
