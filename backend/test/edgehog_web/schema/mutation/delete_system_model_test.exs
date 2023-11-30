#
# This file is part of Edgehog.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.DeleteSystemModelTest do
  use EdgehogWeb.ConnCase, async: true

  alias Edgehog.Devices.SystemModel

  describe "deleteSystemModel field" do
    import Edgehog.DevicesFixtures

    @query """
    mutation DeleteSystemModel($input: DeleteSystemModelInput!) {
      deleteSystemModel(input: $input) {
        systemModel {
          id
          name
          handle
          partNumbers
          description
        }
      }
    }
    """

    test "deletes system model", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      name = "Foobaz"
      handle = "foobaz"
      part_number = "12345/Z"

      default_description_locale = tenant.default_locale
      default_description_text = "A system model"

      description = %{
        default_description_locale => default_description_text,
        "it-IT" => "Un modello di sistema"
      }

      %SystemModel{id: id} =
        system_model_fixture(
          description: description,
          name: name,
          handle: handle,
          part_numbers: [part_number]
        )

      id = Absinthe.Relay.Node.to_global_id(:system_model, id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          system_model_id: id
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "deleteSystemModel" => %{
                   "systemModel" => %{
                     "id" => ^id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "partNumbers" => [^part_number],
                     "description" => ^default_description_text
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns the explicit locale description", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      description = %{default_locale => "A system model", "it-IT" => "Un modello di sistema"}

      %SystemModel{id: id} = system_model_fixture(description: description)

      variables = %{
        input: %{
          system_model_id: Absinthe.Relay.Node.to_global_id(:system_model, id, EdgehogWeb.Schema)
        }
      }

      conn =
        conn
        |> put_req_header("accept-language", "it-IT")
        |> post(api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "deleteSystemModel" => %{
                   "systemModel" => %{
                     "description" => "Un modello di sistema"
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "fails with non-existing id", %{conn: conn, api_path: api_path} do
      id = Absinthe.Relay.Node.to_global_id(:system_model, 10_000_000, EdgehogWeb.Schema)

      variables = %{
        input: %{
          system_model_id: id
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => [%{"code" => "not_found", "status_code" => 404}]} =
               json_response(conn, 200)
    end
  end
end
