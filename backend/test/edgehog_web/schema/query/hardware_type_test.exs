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

defmodule EdgehogWeb.Schema.Query.HardwareTypeTest do
  use EdgehogWeb.ConnCase

  import Edgehog.DevicesFixtures

  alias Edgehog.Devices.{
    HardwareType,
    HardwareTypePartNumber
  }

  describe "hardwareType field" do
    @query """
    query ($id: ID!) {
      hardwareType(id: $id) {
        name
        handle
        partNumbers
      }
    }
    """
    test "returns hardware type if present", %{conn: conn, api_path: api_path} do
      %HardwareType{
        id: id,
        name: name,
        handle: handle,
        part_numbers: [%HardwareTypePartNumber{part_number: part_number}]
      } = hardware_type_fixture()

      variables = %{id: Absinthe.Relay.Node.to_global_id(:hardware_type, id, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "hardwareType" => %{
                   "name" => name,
                   "handle" => handle,
                   "partNumbers" => [part_number]
                 }
               }
             }
    end

    test "raises if non existing", %{conn: conn, api_path: api_path} do
      variables = %{id: Absinthe.Relay.Node.to_global_id(:hardware_type, 1, EdgehogWeb.Schema)}

      conn = get(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{"hardwareType" => nil},
               "errors" => [%{"code" => "not_found", "status_code" => 404}]
             } = json_response(conn, 200)
    end
  end
end
