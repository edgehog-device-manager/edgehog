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

defmodule EdgehogWeb.Schema.Mutation.UpdateSystemModelTest do
  use EdgehogWeb.ConnCase

  alias Edgehog.Devices
  alias Edgehog.Devices.SystemModel

  describe "updateSystemModel field" do
    import Edgehog.DevicesFixtures

    setup %{tenant: tenant} do
      hardware_type = hardware_type_fixture()

      descriptions = [
        %{locale: tenant.default_locale, text: "A system model"},
        %{locale: "it-IT", text: "Un modello di sistema"}
      ]

      {:ok, system_model: system_model_fixture(hardware_type, descriptions: descriptions)}
    end

    @query """
    mutation UpdateSystemModel($input: UpdateSystemModelInput!) {
      updateSystemModel(input: $input) {
        systemModel {
          id
          name
          handle
          partNumbers
          description {
            locale
            text
          }
        }
      }
    }
    """
    test "updates system model with valid data", %{
      conn: conn,
      api_path: api_path,
      system_model: system_model
    } do
      name = "Foobaz"
      handle = "foobaz"
      part_number = "12345/Z"

      id = Absinthe.Relay.Node.to_global_id(:system_model, system_model.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          system_model_id: id,
          name: name,
          handle: handle,
          part_numbers: [part_number]
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "updateSystemModel" => %{
                   "systemModel" => %{
                     "id" => ^id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "partNumbers" => [^part_number]
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      assert {:ok, %SystemModel{name: ^name, handle: ^handle}} =
               Devices.fetch_system_model(system_model.id)
    end

    test "fails with invalid data", %{
      conn: conn,
      api_path: api_path,
      system_model: system_model
    } do
      id = Absinthe.Relay.Node.to_global_id(:system_model, system_model.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          system_model_id: id,
          name: nil,
          handle: nil,
          part_numbers: []
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => _} = assert(json_response(conn, 200))
    end

    test "updates system model with partial data", %{
      conn: conn,
      api_path: api_path,
      system_model: system_model
    } do
      name = "Foobarbaz"

      id = Absinthe.Relay.Node.to_global_id(:system_model, system_model.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          system_model_id: id,
          name: name
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "updateSystemModel" => %{
                   "systemModel" => %{
                     "name" => ^name
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      assert {:ok, %SystemModel{name: ^name}} = Devices.fetch_system_model(system_model.id)
    end

    test "fails with non-existing id", %{conn: conn, api_path: api_path} do
      name = "Foobaz"
      handle = "foobaz"
      part_number = "12345/Z"

      id = Absinthe.Relay.Node.to_global_id(:system_model, 10_000_000, EdgehogWeb.Schema)

      variables = %{
        input: %{
          system_model_id: id,
          name: name,
          handle: handle,
          part_numbers: [part_number]
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => [%{"code" => "not_found", "status_code" => 404}]} =
               assert(json_response(conn, 200))
    end

    test "updates default locale description, without touching the others", %{
      conn: conn,
      api_path: api_path,
      system_model: system_model,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      description = %{
        locale: default_locale,
        text: "Another system model"
      }

      id = Absinthe.Relay.Node.to_global_id(:system_model, system_model.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          system_model_id: id,
          description: description
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "updateSystemModel" => %{
                   "systemModel" => %{
                     "description" => %{
                       "locale" => ^default_locale,
                       "text" => "Another system model"
                     }
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      assert {:ok, system_model} = Devices.fetch_system_model(system_model.id)

      assert %SystemModel{descriptions: [%{locale: "en-US", text: "Another system model"}]} =
               Devices.preload_localized_descriptions_for_system_model(
                 system_model,
                 [default_locale]
               )

      assert %SystemModel{descriptions: [%{locale: "it-IT", text: "Un modello di sistema"}]} =
               Devices.preload_localized_descriptions_for_system_model(
                 system_model,
                 ["it-IT"]
               )
    end

    test "fails when trying to update a non default locale", %{
      conn: conn,
      api_path: api_path,
      system_model: system_model
    } do
      description = %{
        locale: "it-IT",
        text: "Un altro dispositivo"
      }

      id = Absinthe.Relay.Node.to_global_id(:system_model, system_model.id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          system_model_id: id,
          description: description
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => [%{"code" => "not_default_locale"}]} = assert(json_response(conn, 200))
    end
  end
end
