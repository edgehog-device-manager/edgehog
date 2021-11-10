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

defmodule EdgehogWeb.Schema.Mutation.UpdateHardwareTypeTest do
  use EdgehogWeb.ConnCase

  alias Edgehog.Appliances
  alias Edgehog.Appliances.HardwareType

  describe "updateHardwareType field" do
    import Edgehog.AppliancesFixtures

    setup do
      {:ok, hardware_type: hardware_type_fixture()}
    end

    @query """
    mutation UpdateHardwareType($input: UpdateHardwareTypeInput!) {
      updateHardwareType(input: $input) {
        hardwareType {
          id
          name
          handle
          partNumbers
        }
      }
    }
    """
    test "updates hardware type with valid data", %{conn: conn, hardware_type: hardware_type} do
      name = "Foobaz"
      handle = "foobaz"
      part_number = "12345/Z"

      id = Absinthe.Relay.Node.to_global_id(:hardware_type, hardware_type.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          id: id,
          hardware_type: %{
            name: name,
            handle: handle,
            part_numbers: [part_number]
          }
        }
      }

      conn = post(conn, "/api", query: @query, variables: variables)

      assert %{
               "data" => %{
                 "updateHardwareType" => %{
                   "hardwareType" => %{
                     "id" => ^id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "partNumbers" => [^part_number]
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      assert {:ok, %HardwareType{name: ^name, handle: ^handle}} =
               Appliances.fetch_hardware_type(hardware_type.id)
    end

    test "fails with invalid data", %{conn: conn, hardware_type: hardware_type} do
      id = Absinthe.Relay.Node.to_global_id(:hardware_type, hardware_type.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          id: id,
          hardware_type: %{
            name: nil,
            handle: nil,
            part_numbers: []
          }
        }
      }

      conn = post(conn, "/api", query: @query, variables: variables)

      assert %{"errors" => _} = assert(json_response(conn, 200))
    end

    test "fails with non-existing id", %{conn: conn} do
      name = "Foobaz"
      handle = "foobaz"
      part_number = "12345/Z"

      id = Absinthe.Relay.Node.to_global_id(:hardware_type, 10_000_000, EdgehogWeb.Schema)

      variables = %{
        input: %{
          id: id,
          hardware_type: %{
            name: name,
            handle: handle,
            part_numbers: [part_number]
          }
        }
      }

      conn = post(conn, "/api", query: @query, variables: variables)

      assert %{"errors" => [%{"code" => "not_found", "status_code" => 404}]} =
               assert(json_response(conn, 200))
    end
  end
end
