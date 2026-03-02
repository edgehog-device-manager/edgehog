#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.CreateRepositoryTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.FilesFixtures

  describe "createRepository mutation" do
    test "creates repository with valid data", %{tenant: tenant} do
      repository =
        [tenant: tenant, name: "Foobar", handle: "foobar"]
        |> create_repository_mutation()
        |> extract_result!()

      assert %{
               "id" => _,
               "name" => "Foobar",
               "handle" => "foobar",
               "files" => %{
                 "count" => 0,
                 "edges" => []
               }
             } = repository
    end

    test "returns error for missing name", %{tenant: tenant} do
      result =
        create_repository_mutation(
          tenant: tenant,
          name: nil
        )

      assert %{message: message} = extract_error!(result)
      assert String.contains?(message, ~s<In field "name": Expected type "String!">)
    end

    test "returns error for missing handle", %{tenant: tenant} do
      result =
        create_repository_mutation(
          tenant: tenant,
          handle: nil
        )

      assert %{message: message} = extract_error!(result)
      assert String.contains?(message, ~s<In field "handle": Expected type "String!">)
    end

    test "returns error for empty name", %{tenant: tenant} do
      result =
        create_repository_mutation(
          tenant: tenant,
          name: ""
        )

      assert %{fields: [:name], message: "is required"} =
               extract_error!(result)
    end

    test "returns error for empty handle", %{tenant: tenant} do
      result =
        create_repository_mutation(
          tenant: tenant,
          handle: ""
        )

      assert %{fields: [:handle], message: "is required"} =
               extract_error!(result)
    end

    test "returns error for invalid handle", %{tenant: tenant} do
      result =
        create_repository_mutation(
          tenant: tenant,
          handle: "123Invalid$"
        )

      assert %{fields: [:handle], message: "should start with" <> _} =
               extract_error!(result)
    end

    test "returns error for duplicate name", %{tenant: tenant} do
      fixture = repository_fixture(tenant: tenant)

      result =
        create_repository_mutation(
          tenant: tenant,
          name: fixture.name
        )

      assert %{fields: [:name], message: "has already been taken"} =
               extract_error!(result)
    end

    test "returns error for duplicate handle", %{tenant: tenant} do
      fixture = repository_fixture(tenant: tenant)

      result =
        create_repository_mutation(
          tenant: tenant,
          handle: fixture.handle
        )

      assert %{fields: [:handle], message: "has already been taken"} =
               extract_error!(result)
    end
  end

  defp create_repository_mutation(opts) do
    default_document = """
    mutation CreateRepository($input: CreateRepositoryInput!) {
      createRepository(input: $input) {
        result {
          id
          name
          handle
          files {
            count
            edges {
              node {
                id
                name
              }
            }
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {handle, opts} = Keyword.pop_lazy(opts, :handle, &unique_repository_handle/0)
    {name, opts} = Keyword.pop_lazy(opts, :name, &unique_repository_name/0)

    input = %{
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
    assert is_nil(result[:data]["createRepository"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createRepository" => %{
                 "result" => repository
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert repository

    repository
  end
end
