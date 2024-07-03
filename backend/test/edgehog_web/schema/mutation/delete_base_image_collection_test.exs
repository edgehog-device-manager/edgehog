#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures
  alias Edgehog.BaseImages.BaseImageCollection
  require Ash.Query

  describe "deleteBaseImageCollection mutation" do
    setup %{tenant: tenant} do
      base_image_collection =
        base_image_collection_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(base_image_collection)

      %{base_image_collection: base_image_collection, id: id}
    end

    test "deletes the base image collection", %{
      tenant: tenant,
      id: id,
      base_image_collection: fixture
    } do
      base_image_collection =
        delete_base_image_collection_mutation(tenant: tenant, id: id)
        |> extract_result!()

      assert base_image_collection["handle"] == fixture.handle

      refute BaseImageCollection
             |> Ash.Query.filter(id == ^fixture.id)
             |> Ash.Query.set_tenant(tenant)
             |> Ash.exists?()
    end

    test "fails with non-existing id", %{tenant: tenant} do
      id = non_existing_base_image_collection_id(tenant)

      result = delete_base_image_collection_mutation(tenant: tenant, id: id)

      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end
  end

  defp delete_base_image_collection_mutation(opts) do
    default_document = """
    mutation DeleteBaseImageCollection($id: ID!) {
      deleteBaseImageCollection(id: $id) {
        result {
          id
          name
          handle
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    document = Keyword.get(opts, :document, default_document)
    variables = %{"id" => id}
    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"deleteBaseImageCollection" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteBaseImageCollection" => %{
                 "result" => base_image_collection
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert base_image_collection != nil

    base_image_collection
  end

  defp non_existing_base_image_collection_id(tenant) do
    fixture = base_image_collection_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end
end
