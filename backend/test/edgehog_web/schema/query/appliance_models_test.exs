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
        description {
          locale
          text
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

    test "returns the default locale description", %{conn: conn, tenant: tenant} do
      hardware_type = hardware_type_fixture()

      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "An appliance"},
        %{locale: "it-IT", text: "Un dispositivo"}
      ]

      _appliance_model = appliance_model_fixture(hardware_type, descriptions: descriptions)

      conn = get(conn, "/api", query: @query)

      assert %{
               "data" => %{
                 "applianceModels" => [appliance_model]
               }
             } = json_response(conn, 200)

      assert appliance_model["description"]["locale"] == default_locale
      assert appliance_model["description"]["text"] == "An appliance"
    end

    test "returns an explicit locale description", %{conn: conn, tenant: tenant} do
      hardware_type = hardware_type_fixture()

      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "An appliance"},
        %{locale: "it-IT", text: "Un dispositivo"}
      ]

      _appliance_model = appliance_model_fixture(hardware_type, descriptions: descriptions)

      conn =
        conn
        |> put_req_header("accept-language", "it-IT")
        |> get("/api", query: @query)

      assert %{
               "data" => %{
                 "applianceModels" => [appliance_model]
               }
             } = json_response(conn, 200)

      assert appliance_model["description"]["locale"] == "it-IT"
      assert appliance_model["description"]["text"] == "Un dispositivo"
    end

    test "returns empty description for non existing locale", %{conn: conn, tenant: tenant} do
      hardware_type = hardware_type_fixture()

      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "An appliance"},
        %{locale: "it-IT", text: "Un dispositivo"}
      ]

      _appliance_model = appliance_model_fixture(hardware_type, descriptions: descriptions)

      conn =
        conn
        |> put_req_header("accept-language", "fr-FR")
        |> get("/api", query: @query)

      assert %{
               "data" => %{
                 "applianceModels" => [appliance_model]
               }
             } = json_response(conn, 200)

      assert appliance_model["description"] == nil
    end
  end
end
