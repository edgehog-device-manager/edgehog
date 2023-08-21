#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.CreateBaseImageCollectionTest do
  use EdgehogWeb.ConnCase, async: true

  alias Edgehog.BaseImages
  alias Edgehog.BaseImages.BaseImageCollection

  import Edgehog.DevicesFixtures

  describe "createBaseImageCollection field" do
    setup do
      hardware_type = hardware_type_fixture()

      {:ok, system_model: system_model_fixture(hardware_type)}
    end

    @query """
    mutation CreateBaseImageCollection($input: CreateBaseImageCollectionInput!) {
      createBaseImageCollection(input: $input) {
        baseImageCollection {
          id
          name
          handle
          systemModel {
            id
            name
            handle
          }
        }
      }
    }
    """
    test "creates base image collection with valid data", %{
      conn: conn,
      api_path: api_path,
      system_model: system_model
    } do
      name = "Foobar"
      handle = "foobar"

      system_model_id =
        Absinthe.Relay.Node.to_global_id(:system_model, system_model.id, EdgehogWeb.Schema)

      system_model_name = system_model.name
      system_model_handle = system_model.handle

      variables = %{
        input: %{
          name: name,
          handle: handle,
          system_model_id: system_model_id
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "createBaseImageCollection" => %{
                   "baseImageCollection" => %{
                     "id" => id,
                     "name" => ^name,
                     "handle" => ^handle,
                     "systemModel" => %{
                       "id" => ^system_model_id,
                       "name" => ^system_model_name,
                       "handle" => ^system_model_handle
                     }
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      {:ok, %{type: :base_image_collection, id: db_id}} =
        Absinthe.Relay.Node.from_global_id(id, EdgehogWeb.Schema)

      assert {:ok, %BaseImageCollection{name: ^name, handle: ^handle}} =
               BaseImages.fetch_base_image_collection(db_id)
    end

    test "fails with invalid data", %{conn: conn, api_path: api_path} do
      variables = %{
        input: %{
          base_image_collection: %{
            name: nil,
            handle: nil
          }
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => _} = assert(json_response(conn, 200))
    end

    test "fails when trying to use a non-existing system model", %{
      conn: conn,
      api_path: api_path
    } do
      name = "Foobar"
      handle = "foobar"

      system_model_id =
        Absinthe.Relay.Node.to_global_id(:system_model, "12345678", EdgehogWeb.Schema)

      variables = %{
        input: %{
          name: name,
          handle: handle,
          system_model_id: system_model_id
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => [%{"status_code" => 404, "code" => "not_found"}]} =
               assert(json_response(conn, 200))
    end
  end
end
