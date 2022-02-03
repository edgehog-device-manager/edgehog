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

defmodule EdgehogWeb.Schema.Query.HardwareTypesTest do
  use EdgehogWeb.ConnCase

  import Edgehog.DevicesFixtures

  alias Edgehog.Devices.{
    HardwareType,
    HardwareTypePartNumber
  }

  describe "hardwareTypes field" do
    @query """
    {
      hardwareTypes {
        name
        handle
        partNumbers
      }
    }
    """
    test "returns empty hardware types", %{conn: conn} do
      conn = get(conn, "/api", query: @query)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "hardwareTypes" => []
               }
             }
    end

    test "returns hardware types if they're present", %{conn: conn} do
      %HardwareType{
        name: name,
        handle: handle,
        part_numbers: [%HardwareTypePartNumber{part_number: part_number}]
      } = hardware_type_fixture()

      conn = get(conn, "/api", query: @query)

      assert %{
               "data" => %{
                 "hardwareTypes" => [hardware_type]
               }
             } = json_response(conn, 200)

      assert hardware_type["name"] == name
      assert hardware_type["handle"] == handle
      assert hardware_type["partNumbers"] == [part_number]
    end
  end
end
