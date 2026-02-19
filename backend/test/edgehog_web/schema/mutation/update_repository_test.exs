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

defmodule EdgehogWeb.Schema.Mutation.UpdateRepositoryTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.FilesFixtures

  describe "updateRepository mutation" do
    setup %{tenant: tenant} do
      repo = repository_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(repo)
      %{repository: repo, id: id}
    end

    test "updates repository with valid data", %{tenant: tenant, id: id} do
      result =
        [tenant: tenant, id: id, name: "Updated Name", handle: "updated-handle"]
        |> update_repository_mutation()
        |> extract_result!()

      assert %{
               "id" => ^id,
               "name" => "Updated Name",
               "handle" => "updated-handle"
             } = result
    end

    test "supports partial update (name only)", %{
      tenant: tenant,
      repository: repo,
      id: id
    } do
      old_handle = repo.handle

      result =
        [tenant: tenant, id: id, name: "Only Name Changed"]
        |> update_repository_mutation()
        |> extract_result!()

      assert result["name"] == "Only Name Changed"
      assert result["handle"] == old_handle
    end

    test "supports partial update (handle only)", %{
      tenant: tenant,
      repository: repo,
      id: id
    } do
      old_name = repo.name

      result =
        [tenant: tenant, id: id, handle: "only-handle-changed"]
        |> update_repository_mutation()
        |> extract_result!()

      assert result["name"] == old_name
      assert result["handle"] == "only-handle-changed"
    end

    test "updates description", %{tenant: tenant, id: id} do
      result =
        [tenant: tenant, id: id, description: "New description"]
        |> update_repository_mutation()
        |> extract_result!()

      assert result["description"] == "New description"
    end

    test "clears description with null", %{tenant: tenant} do
      repo = repository_fixture(tenant: tenant, description: "has description")
      id = AshGraphql.Resource.encode_relay_id(repo)

      document = """
      mutation UpdateRepository($id: ID!, $input: UpdateRepositoryInput!) {
        updateRepository(id: $id, input: $input) {
          result {
            id
            description
          }
        }
      }
      """

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"id" => id, "input" => %{"description" => nil}},
          context: %{tenant: tenant}
        )

      assert %{data: %{"updateRepository" => %{"result" => %{"description" => nil}}}} = result
    end

    test "returns error for empty name", %{tenant: tenant, id: id} do
      result =
        update_repository_mutation(tenant: tenant, id: id, name: "")

      assert %{fields: [:name], message: "is required"} = extract_error!(result)
    end

    test "returns error for empty handle", %{tenant: tenant, id: id} do
      result =
        update_repository_mutation(tenant: tenant, id: id, handle: "")

      assert %{fields: [:handle], message: "is required"} = extract_error!(result)
    end

    test "returns error for duplicate name", %{tenant: tenant, id: id} do
      other = repository_fixture(tenant: tenant)

      result =
        update_repository_mutation(tenant: tenant, id: id, name: other.name)

      assert %{fields: [:name], message: "has already been taken"} = extract_error!(result)
    end

    test "returns error for duplicate handle", %{tenant: tenant, id: id} do
      other = repository_fixture(tenant: tenant)

      result =
        update_repository_mutation(tenant: tenant, id: id, handle: other.handle)

      assert %{fields: [:handle], message: "has already been taken"} = extract_error!(result)
    end

    test "fails with non-existing id", %{tenant: tenant, repository: repo, id: id} do
      _ = Ash.destroy!(repo, tenant: tenant)

      result =
        update_repository_mutation(tenant: tenant, id: id, name: "Updated")

      assert %{fields: [:id], message: "could not be found" <> _} = extract_error!(result)
    end
  end

  defp update_repository_mutation(opts) do
    default_document = """
    mutation UpdateRepository($id: ID!, $input: UpdateRepositoryInput!) {
      updateRepository(id: $id, input: $input) {
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
    {id, opts} = Keyword.pop!(opts, :id)

    input =
      %{
        "name" => opts[:name],
        "handle" => opts[:handle],
        "description" => opts[:description]
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    variables = %{"id" => id, "input" => input}
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant}
    )
  end

  defp extract_error!(result) do
    assert %{
             data: %{"updateRepository" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateRepository" => %{
                 "result" => repository
               }
             }
           } = result

    refute Map.get(result, :errors)
    assert repository

    repository
  end
end
