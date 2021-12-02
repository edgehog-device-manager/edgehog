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

defmodule EdgehogWeb.Schema.Query.ApplianceModelTest do
  use EdgehogWeb.ConnCase

  import Edgehog.AppliancesFixtures

  alias Edgehog.Appliances.{
    ApplianceModel,
    ApplianceModelPartNumber
  }

  describe "applianceModel field" do
    @query """
    query ($id: ID!) {
      applianceModel(id: $id) {
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
    test "returns appliance model if present", %{conn: conn} do
      hardware_type = hardware_type_fixture()

      %ApplianceModel{
        id: id,
        name: name,
        handle: handle,
        part_numbers: [%ApplianceModelPartNumber{part_number: part_number}]
      } = appliance_model_fixture(hardware_type)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:appliance_model, id, EdgehogWeb.Schema)}

      conn = get(conn, "/api", query: @query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "applianceModel" => %{
                   "name" => name,
                   "handle" => handle,
                   "partNumbers" => [part_number],
                   "hardwareType" => %{
                     "name" => hardware_type.name
                   },
                   "description" => nil
                 }
               }
             }
    end

    test "returns not found if non existing", %{conn: conn} do
      variables = %{id: Absinthe.Relay.Node.to_global_id(:appliance_model, 1, EdgehogWeb.Schema)}

      conn = get(conn, "/api", query: @query, variables: variables)

      assert %{
               "data" => %{"applianceModel" => nil},
               "errors" => [%{"code" => "not_found", "status_code" => 404}]
             } = json_response(conn, 200)
    end

    test "returns the default locale description", %{conn: conn, tenant: tenant} do
      hardware_type = hardware_type_fixture()

      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "An appliance"},
        %{locale: "it-IT", text: "Un dispositivo"}
      ]

      %ApplianceModel{id: id} = appliance_model_fixture(hardware_type, descriptions: descriptions)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:appliance_model, id, EdgehogWeb.Schema)}

      conn = get(conn, "/api", query: @query, variables: variables)

      assert %{
               "data" => %{
                 "applianceModel" => %{
                   "description" => %{
                     "locale" => ^default_locale,
                     "text" => "An appliance"
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns the explicit locale description", %{conn: conn, tenant: tenant} do
      hardware_type = hardware_type_fixture()

      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "An appliance"},
        %{locale: "it-IT", text: "Un dispositivo"}
      ]

      %ApplianceModel{id: id} = appliance_model_fixture(hardware_type, descriptions: descriptions)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:appliance_model, id, EdgehogWeb.Schema)}

      conn =
        conn
        |> put_req_header("accept-language", "it-IT")
        |> get("/api", query: @query, variables: variables)

      assert %{
               "data" => %{
                 "applianceModel" => %{
                   "description" => %{
                     "locale" => "it-IT",
                     "text" => "Un dispositivo"
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns empty description for not existing locale", %{conn: conn, tenant: tenant} do
      hardware_type = hardware_type_fixture()

      default_locale = tenant.default_locale

      descriptions = [
        %{locale: default_locale, text: "An appliance"},
        %{locale: "it-IT", text: "Un dispositivo"}
      ]

      %ApplianceModel{id: id} = appliance_model_fixture(hardware_type, descriptions: descriptions)

      variables = %{id: Absinthe.Relay.Node.to_global_id(:appliance_model, id, EdgehogWeb.Schema)}

      conn =
        conn
        |> put_req_header("accept-language", "fr-FR")
        |> get("/api", query: @query, variables: variables)

      assert %{
               "data" => %{
                 "applianceModel" => %{
                   "description" => nil
                 }
               }
             } = json_response(conn, 200)
    end
  end
end
