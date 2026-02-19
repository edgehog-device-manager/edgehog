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
      result =
        [tenant: tenant, name: "My Repository", handle: "my-repository"]
        |> create_repository_mutation()
        |> extract_result!()

      assert %{
               "id" => _,
               "name" => "My Repository",
               "handle" => "my-repository"
             } = result
    end

    test "creates repository with description", %{tenant: tenant} do
      result =
        [
          tenant: tenant,
          name: "Described Repo",
          handle: "described-repo",
          description: "A repo with a description"
        ]
        |> create_repository_mutation()
        |> extract_result!()

      assert result["description"] == "A repo with a description"
    end

    test "creates repository without description (nil)", %{tenant: tenant} do
      result =
        [tenant: tenant, name: "No Desc", handle: "no-desc"]
        |> create_repository_mutation()
        |> extract_result!()

      assert is_nil(result["description"])
    end

    test "returns error for missing name", %{tenant: tenant} do
      result =
        create_repository_mutation(
          tenant: tenant,
          name: nil,
          handle: "some-handle"
        )

      assert %{message: message} = extract_error!(result)
      assert message =~ "name"
    end

    test "returns error for missing handle", %{tenant: tenant} do
      result =
        create_repository_mutation(
          tenant: tenant,
          name: "Some Name",
          handle: nil
        )

      assert %{message: message} = extract_error!(result)
      assert message =~ "handle"
    end

    test "returns error for empty name", %{tenant: tenant} do
      result =
        create_repository_mutation(
          tenant: tenant,
          name: "",
          handle: "valid-handle"
        )

      assert %{fields: [:name], message: "is required"} = extract_error!(result)
    end

    test "returns error for empty handle", %{tenant: tenant} do
      result =
        create_repository_mutation(
          tenant: tenant,
          name: "Valid Name",
          handle: ""
        )

      assert %{fields: [:handle], message: "is required"} = extract_error!(result)
    end

    test "returns error for duplicate name", %{tenant: tenant} do
      fixture = repository_fixture(tenant: tenant)

      result =
        create_repository_mutation(
          tenant: tenant,
          name: fixture.name,
          handle: "different-handle"
        )

      assert %{fields: [:name], message: "has already been taken"} = extract_error!(result)
    end

    test "returns error for duplicate handle", %{tenant: tenant} do
      fixture = repository_fixture(tenant: tenant)

      result =
        create_repository_mutation(
          tenant: tenant,
          name: "Different Name",
          handle: fixture.handle
        )

      assert %{fields: [:handle], message: "has already been taken"} = extract_error!(result)
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
          description
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {name, opts} = Keyword.pop_lazy(opts, :name, &unique_repository_name/0)
    {handle, opts} = Keyword.pop_lazy(opts, :handle, &unique_repository_handle/0)
    description = Keyword.get(opts, :description)

    input =
      %{
        "name" => name,
        "handle" => handle,
        "description" => description
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    variables = %{"input" => input}
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant}
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
