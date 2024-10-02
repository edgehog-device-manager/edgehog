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

defmodule EdgehogWeb.Schema.Mutation.UpdateBaseImageCollectionTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures

  describe "updateBaseImageCollection field" do
    setup %{tenant: tenant} do
      base_image_collection =
        [tenant: tenant]
        |> base_image_collection_fixture()
        |> Ash.load!(:system_model)

      id = AshGraphql.Resource.encode_relay_id(base_image_collection)

      %{base_image_collection: base_image_collection, id: id}
    end

    test "updates base image collection with valid data", %{tenant: tenant, id: id} do
      base_image_collection =
        [tenant: tenant, id: id, name: "Updated Name", handle: "updatedhandle"]
        |> update_base_image_collection_mutation()
        |> extract_result!()

      assert %{
               "id" => ^id,
               "name" => "Updated Name",
               "handle" => "updatedhandle"
             } = base_image_collection
    end

    test "supports partial updates", %{
      tenant: tenant,
      base_image_collection: base_image_collection,
      id: id
    } do
      %{handle: old_handle} = base_image_collection

      base_image_collection =
        [tenant: tenant, id: id, name: "Updated Name"]
        |> update_base_image_collection_mutation()
        |> extract_result!()

      assert %{
               "name" => "Updated Name",
               "handle" => ^old_handle
             } = base_image_collection
    end

    test "returns error for invalid handle", %{tenant: tenant, id: id} do
      result =
        update_base_image_collection_mutation(
          tenant: tenant,
          id: id,
          handle: "123Invalid$"
        )

      assert %{fields: [:handle], message: "should start with" <> _} =
               extract_error!(result)
    end

    test "returns error for empty handle", %{tenant: tenant, id: id} do
      result =
        update_base_image_collection_mutation(
          tenant: tenant,
          id: id,
          handle: ""
        )

      assert %{fields: [:handle], message: "should start with" <> _} =
               extract_error!(result)
    end

    test "returns error for empty name", %{tenant: tenant, id: id} do
      result =
        update_base_image_collection_mutation(
          tenant: tenant,
          id: id,
          name: ""
        )

      assert %{fields: [:name], message: "is required"} =
               extract_error!(result)
    end

    test "returns error for duplicate name", %{tenant: tenant, id: id} do
      fixture = base_image_collection_fixture(tenant: tenant)

      result =
        update_base_image_collection_mutation(
          tenant: tenant,
          id: id,
          name: fixture.name
        )

      assert %{fields: [:name], message: "has already been taken"} =
               extract_error!(result)
    end

    test "returns error for duplicate handle", %{tenant: tenant, id: id} do
      fixture = base_image_collection_fixture(tenant: tenant)

      result =
        update_base_image_collection_mutation(
          tenant: tenant,
          id: id,
          handle: fixture.handle
        )

      assert %{fields: [:handle], message: "has already been taken"} =
               extract_error!(result)
    end

    test "fails with non-existing id", %{
      tenant: tenant,
      base_image_collection: base_image_collection,
      id: id
    } do
      _ = Ash.destroy!(base_image_collection)

      result =
        update_base_image_collection_mutation(
          tenant: tenant,
          id: id,
          name: "Updated Name"
        )

      assert %{fields: [:id], message: "could not be found" <> _} =
               extract_error!(result)
    end
  end

  defp update_base_image_collection_mutation(opts) do
    default_document = """
    mutation UpdateBaseImageCollection($id: ID!, $input: UpdateBaseImageCollectionInput!) {
      updateBaseImageCollection(id: $id, input: $input) {
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

    input =
      %{
        "handle" => opts[:handle],
        "name" => opts[:name]
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Map.new()

    variables = %{"id" => id, "input" => input}

    document = Keyword.get(opts, :document, default_document)

    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"updateBaseImageCollection" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateBaseImageCollection" => %{
                 "result" => base_image_collection
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert base_image_collection != nil

    base_image_collection
  end
end
