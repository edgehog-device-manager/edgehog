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

defmodule EdgehogWeb.Schema.Mutation.UpdateBaseImageCollectionTest do
  use EdgehogWeb.ConnCase, async: true

  alias Edgehog.BaseImages
  alias Edgehog.BaseImages.BaseImageCollection

  describe "updateBaseImageCollection field" do
    import Edgehog.BaseImagesFixtures

    setup do
      {:ok, base_image_collection: base_image_collection_fixture()}
    end

    @query """
    mutation UpdateBaseImageCollection($input: UpdateBaseImageCollectionInput!) {
      updateBaseImageCollection(input: $input) {
        baseImageCollection {
          id
          name
          handle
        }
      }
    }
    """
    test "updates base image collection with valid data", %{
      conn: conn,
      api_path: api_path,
      base_image_collection: base_image_collection
    } do
      name = "Foobaz"
      handle = "foobaz"

      id =
        Absinthe.Relay.Node.to_global_id(
          :base_image_collection,
          base_image_collection.id,
          EdgehogWeb.Schema
        )

      variables = %{
        input: %{
          base_image_collection_id: id,
          name: name,
          handle: handle
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "updateBaseImageCollection" => %{
                   "baseImageCollection" => %{
                     "id" => ^id,
                     "name" => ^name,
                     "handle" => ^handle
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      assert {:ok, %BaseImageCollection{name: ^name, handle: ^handle}} =
               BaseImages.fetch_base_image_collection(base_image_collection.id)
    end

    test "fails with invalid data", %{
      conn: conn,
      api_path: api_path,
      base_image_collection: base_image_collection
    } do
      id =
        Absinthe.Relay.Node.to_global_id(
          :base_image_collection,
          base_image_collection.id,
          EdgehogWeb.Schema
        )

      variables = %{
        input: %{
          base_image_collection_id: id,
          name: nil,
          handle: nil
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => _} = assert(json_response(conn, 200))
    end

    test "updates base image collection with partial data", %{
      conn: conn,
      api_path: api_path,
      base_image_collection: base_image_collection
    } do
      name = "Foobarbaz"

      id =
        Absinthe.Relay.Node.to_global_id(
          :base_image_collection,
          base_image_collection.id,
          EdgehogWeb.Schema
        )

      variables = %{
        input: %{
          base_image_collection_id: id,
          name: name
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "updateBaseImageCollection" => %{
                   "baseImageCollection" => %{
                     "name" => ^name
                   }
                 }
               }
             } = assert(json_response(conn, 200))

      assert {:ok, %BaseImageCollection{name: ^name}} =
               BaseImages.fetch_base_image_collection(base_image_collection.id)
    end

    test "fails with non-existing id", %{conn: conn, api_path: api_path} do
      name = "Foobaz"
      handle = "foobaz"

      id = Absinthe.Relay.Node.to_global_id(:base_image_collection, 10_000_000, EdgehogWeb.Schema)

      variables = %{
        input: %{
          base_image_collection_id: id,
          name: name,
          handle: handle
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => [%{"code" => "not_found", "status_code" => 404}]} =
               assert(json_response(conn, 200))
    end
  end
end
