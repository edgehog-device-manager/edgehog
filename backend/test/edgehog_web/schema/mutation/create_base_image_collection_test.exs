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

defmodule EdgehogWeb.Schema.Mutation.CreateBaseImageCollectionTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures

  describe "createBaseImageCollection mutation" do
    test "creates base image collection with valid data", %{tenant: tenant} do
      system_model = system_model_fixture(tenant: tenant)
      system_model_id = AshGraphql.Resource.encode_relay_id(system_model)
      system_model_name = system_model.name
      system_model_handle = system_model.handle

      base_image_collection =
        [tenant: tenant, system_model_id: system_model_id, name: "Foobar", handle: "foobar"]
        |> create_base_image_collection_mutation()
        |> extract_result!()

      assert %{
               "id" => _,
               "name" => "Foobar",
               "handle" => "foobar",
               "systemModel" => %{
                 "id" => ^system_model_id,
                 "name" => ^system_model_name,
                 "handle" => ^system_model_handle
               }
             } = base_image_collection
    end

    test "returns error for non-existing system model", %{tenant: tenant} do
      system_model = system_model_fixture(tenant: tenant)
      system_model_id = AshGraphql.Resource.encode_relay_id(system_model)
      _ = Ash.destroy!(system_model)

      result =
        create_base_image_collection_mutation(
          tenant: tenant,
          system_model_id: system_model_id
        )

      # TODO: wrong fields returned by AshGraphql
      assert %{fields: [:id], message: "could not be found" <> _} =
               extract_error!(result)
    end

    test "returns error for missing name", %{tenant: tenant} do
      result =
        create_base_image_collection_mutation(
          tenant: tenant,
          name: nil
        )

      assert %{message: message} = extract_error!(result)
      assert String.contains?(message, ~s<In field "name": Expected type "String!">)
    end

    test "returns error for missing handle", %{tenant: tenant} do
      result =
        create_base_image_collection_mutation(
          tenant: tenant,
          handle: nil
        )

      assert %{message: message} = extract_error!(result)
      assert String.contains?(message, ~s<In field "handle": Expected type "String!">)
    end

    test "returns error for empty name", %{tenant: tenant} do
      result =
        create_base_image_collection_mutation(
          tenant: tenant,
          name: ""
        )

      assert %{fields: [:name], message: "is required"} =
               extract_error!(result)
    end

    test "returns error for empty handle", %{tenant: tenant} do
      result =
        create_base_image_collection_mutation(
          tenant: tenant,
          handle: ""
        )

      assert %{fields: [:handle], message: "is required"} =
               extract_error!(result)
    end

    test "returns error for invalid handle", %{tenant: tenant} do
      result =
        create_base_image_collection_mutation(
          tenant: tenant,
          handle: "123Invalid$"
        )

      assert %{fields: [:handle], message: "should start with" <> _} =
               extract_error!(result)
    end

    test "returns error for duplicate name", %{tenant: tenant} do
      fixture = base_image_collection_fixture(tenant: tenant)

      result =
        create_base_image_collection_mutation(
          tenant: tenant,
          name: fixture.name
        )

      assert %{fields: [:name], message: "has already been taken"} =
               extract_error!(result)
    end

    test "returns error for duplicate handle", %{tenant: tenant} do
      fixture = base_image_collection_fixture(tenant: tenant)

      result =
        create_base_image_collection_mutation(
          tenant: tenant,
          handle: fixture.handle
        )

      assert %{fields: [:handle], message: "has already been taken"} =
               extract_error!(result)
    end
  end

  defp create_base_image_collection_mutation(opts) do
    default_document = """
    mutation CreateBaseImageCollection($input: CreateBaseImageCollectionInput!) {
      createBaseImageCollection(input: $input) {
        result {
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

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {system_model_id, opts} =
      Keyword.pop_lazy(opts, :system_model_id, fn ->
        [tenant: tenant]
        |> system_model_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {handle, opts} = Keyword.pop_lazy(opts, :handle, &unique_base_image_collection_handle/0)
    {name, opts} = Keyword.pop_lazy(opts, :name, &unique_base_image_collection_name/0)

    input = %{
      "systemModelId" => system_model_id,
      "handle" => handle,
      "name" => name
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: context
    )
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["createBaseImageCollection"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createBaseImageCollection" => %{
                 "result" => base_image_collection
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert base_image_collection != nil

    base_image_collection
  end
end
