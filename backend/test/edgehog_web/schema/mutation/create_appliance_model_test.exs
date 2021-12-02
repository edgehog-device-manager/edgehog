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

defmodule EdgehogWeb.Schema.Mutation.CreateApplianceModelTest do
  use EdgehogWeb.ConnCase

  alias Edgehog.Appliances
  alias Edgehog.Appliances.ApplianceModel

  import Edgehog.AppliancesFixtures

  describe "createApplianceModel field" do
    setup do
      {:ok, hardware_type: hardware_type_fixture()}
    end

    @query """
    mutation CreateApplianceModel($input: CreateApplianceModelInput!) {
      createApplianceModel(input: $input) {
        applianceModel {
          id
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
    }
    """
    test "creates appliance model with valid data", %{conn: conn, hardware_type: hardware_type} do
      name = "Foobar"
      handle = "foobar"
      part_number = "12345/X"

      hardware_type_name = hardware_type.name

      hardware_type_id =
        Absinthe.Relay.Node.to_global_id(:hardware_type, hardware_type.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          name: name,
          handle: handle,
          part_numbers: [part_number],
          hardware_type_id: hardware_type_id
        }
      }

      conn = post(conn, "/api", query: @query, variables: variables)

      assert %{
               "data" => %{
                 "createApplianceModel" => %{
                   "applianceModel" => %{
                     "id" => id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "partNumbers" => [^part_number],
                     "hardwareType" => %{
                       "name" => ^hardware_type_name
                     },
                     "description" => nil
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      {:ok, %{type: :appliance_model, id: db_id}} =
        Absinthe.Relay.Node.from_global_id(id, EdgehogWeb.Schema)

      assert {:ok, %ApplianceModel{name: ^name, handle: ^handle}} =
               Appliances.fetch_appliance_model(db_id)
    end

    test "fails with invalid data", %{conn: conn} do
      variables = %{
        input: %{
          appliance_model: %{
            name: nil,
            handle: nil,
            part_numbers: []
          }
        }
      }

      conn = post(conn, "/api", query: @query, variables: variables)

      assert %{"errors" => _} = assert(json_response(conn, 200))
    end

    test "allows settings a description for the default locale", %{
      conn: conn,
      hardware_type: hardware_type,
      tenant: tenant
    } do
      name = "Foobar"
      handle = "foobar"
      part_number = "12345/X"

      hardware_type_name = hardware_type.name

      hardware_type_id =
        Absinthe.Relay.Node.to_global_id(:hardware_type, hardware_type.id, EdgehogWeb.Schema)

      default_locale = tenant.default_locale

      variables = %{
        input: %{
          name: name,
          handle: handle,
          part_numbers: [part_number],
          hardware_type_id: hardware_type_id,
          description: %{
            locale: default_locale,
            text: "An appliance"
          }
        }
      }

      conn = post(conn, "/api", query: @query, variables: variables)

      assert %{
               "data" => %{
                 "createApplianceModel" => %{
                   "applianceModel" => %{
                     "id" => id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "partNumbers" => [^part_number],
                     "hardwareType" => %{
                       "name" => ^hardware_type_name
                     },
                     "description" => %{
                       "locale" => ^default_locale,
                       "text" => "An appliance"
                     }
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      {:ok, %{type: :appliance_model, id: db_id}} =
        Absinthe.Relay.Node.from_global_id(id, EdgehogWeb.Schema)

      assert {:ok, %ApplianceModel{name: ^name, handle: ^handle}} =
               Appliances.fetch_appliance_model(db_id)
    end

    test "fails when trying to set a description for non default locale", %{
      conn: conn,
      hardware_type: hardware_type
    } do
      name = "Foobar"
      handle = "foobar"
      part_number = "12345/X"

      hardware_type_id =
        Absinthe.Relay.Node.to_global_id(:hardware_type, hardware_type.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          name: name,
          handle: handle,
          part_numbers: [part_number],
          hardware_type_id: hardware_type_id,
          description: %{
            locale: "it-IT",
            text: "Un dispositivo"
          }
        }
      }

      conn = post(conn, "/api", query: @query, variables: variables)

      assert %{"errors" => [%{"code" => "not_default_locale"}]} = assert(json_response(conn, 200))
    end
  end
end
