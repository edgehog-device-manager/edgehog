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

defmodule EdgehogWeb.Schema.Query.ApplianceModelsTest do
  use EdgehogWeb.ConnCase

  import Edgehog.AppliancesFixtures

  alias Edgehog.Appliances.{
    ApplianceModel,
    ApplianceModelPartNumber
  }

  describe "applianceModels field" do
    @query """
    {
      applianceModels {
        name
        handle
        partNumbers
        hardwareType {
          name
        }
      }
    }
    """
    test "returns empty appliance models", %{conn: conn} do
      conn = get(conn, "/api", query: @query)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "applianceModels" => []
               }
             }
    end

    test "returns appliance models if they're present", %{conn: conn} do
      hardware_type = hardware_type_fixture()

      %ApplianceModel{
        name: name,
        handle: handle,
        part_numbers: [%ApplianceModelPartNumber{part_number: part_number}]
      } = appliance_model_fixture(hardware_type)

      conn = get(conn, "/api", query: @query)

      assert %{
               "data" => %{
                 "applianceModels" => [appliance_model]
               }
             } = json_response(conn, 200)

      assert appliance_model["name"] == name
      assert appliance_model["handle"] == handle
      assert appliance_model["partNumbers"] == [part_number]
      assert appliance_model["hardwareType"]["name"] == hardware_type.name
    end
  end
end
