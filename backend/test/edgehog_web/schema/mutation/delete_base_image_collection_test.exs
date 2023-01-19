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

defmodule EdgehogWeb.Schema.Mutation.DeleteBaseImageCollectionTest do
  use EdgehogWeb.ConnCase

  alias Edgehog.BaseImages.BaseImageCollection

  describe "deleteBaseImageCollection field" do
    import Edgehog.DevicesFixtures
    import Edgehog.BaseImagesFixtures

    setup do
      hardware_type = hardware_type_fixture()
      {:ok, hardware_type: hardware_type}
    end

    @query """
    mutation DeleteBaseImageCollection($input: DeleteBaseImageCollectionInput!) {
      deleteBaseImageCollection(input: $input) {
        baseImageCollection {
          id
          name
          handle
          systemModel {
            description
          }
        }
      }
    }
    """

    test "deletes the base image collection", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant,
      hardware_type: hardware_type
    } do
      default_description_locale = tenant.default_locale
      default_description_text = "A system model"

      description = %{
        default_description_locale => default_description_text,
        "it-IT" => "Un modello di sistema"
      }

      system_model = system_model_fixture(hardware_type, description: description)

      name = "Ultimate Firmware"
      handle = "ultimate-firmware"

      %BaseImageCollection{id: id} =
        base_image_collection_fixture(system_model,
          name: name,
          handle: handle,
          system_model: system_model
        )

      id = Absinthe.Relay.Node.to_global_id(:base_image_collection, id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          base_image_collection_id: id
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "deleteBaseImageCollection" => %{
                   "baseImageCollection" => %{
                     "id" => ^id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "systemModel" => %{
                       "description" => ^default_description_text
                     }
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns the explicit locale description of the system model", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant,
      hardware_type: hardware_type
    } do
      default_locale = tenant.default_locale

      description = %{
        default_locale => "A system model",
        "it-IT" => "Un modello di sistema"
      }

      system_model = system_model_fixture(hardware_type, description: description)

      name = "Ultimate Firmware"
      handle = "ultimate-firmware"

      %BaseImageCollection{id: id} =
        base_image_collection_fixture(system_model,
          name: name,
          handle: handle,
          system_model: system_model
        )

      id = Absinthe.Relay.Node.to_global_id(:base_image_collection, id, EdgehogWeb.Schema)

      variables = %{
        input: %{
          base_image_collection_id: id
        }
      }

      conn =
        conn
        |> put_req_header("accept-language", "it-IT")
        |> post(api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "deleteBaseImageCollection" => %{
                   "baseImageCollection" => %{
                     "id" => ^id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "systemModel" => %{
                       "description" => "Un modello di sistema"
                     }
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "fails with non-existing id", %{conn: conn, api_path: api_path} do
      id = Absinthe.Relay.Node.to_global_id(:base_image_collection, 10_000_000, EdgehogWeb.Schema)

      variables = %{
        input: %{
          base_image_collection_id: id
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => [%{"code" => "not_found", "status_code" => 404}]} =
               json_response(conn, 200)
    end
  end
end
