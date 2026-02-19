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

defmodule EdgehogWeb.Schema.Mutation.DeleteRepositoryTest do
  @moduledoc false

  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.FilesFixtures

  describe "deleteRepository mutation" do
    setup %{tenant: tenant} do
      repo = repository_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(repo)
      %{repository: repo, id: id}
    end

    test "deletes an existing repository", %{tenant: tenant, id: id} do
      result =
        [tenant: tenant, id: id]
        |> delete_repository_mutation()
        |> extract_result!()

      assert result["id"] == id
    end

    test "returns error for non-existing repository", %{
      tenant: tenant,
      repository: repo,
      id: id
    } do
      _ = Ash.destroy!(repo, tenant: tenant)

      result = delete_repository_mutation(tenant: tenant, id: id)

      assert %{message: "could not be found" <> _} = extract_error!(result)
    end

    test "verifies repository is actually deleted", %{tenant: tenant, id: id} do
      delete_repository_mutation(tenant: tenant, id: id)

      document = """
      query GetRepository($id: ID!) {
        repository(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"id" => id},
          context: %{tenant: tenant}
        )

      assert %{data: %{"repository" => nil}} = result
    end
  end

  defp delete_repository_mutation(opts) do
    document = """
    mutation DeleteRepository($id: ID!) {
      deleteRepository(id: $id) {
        result {
          id
          name
          handle
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: %{"id" => id},
      context: %{tenant: tenant}
    )
  end

  defp extract_error!(result) do
    assert %{
             data: %{"deleteRepository" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteRepository" => %{
                 "result" => repository
               }
             }
           } = result

    refute Map.get(result, :errors)
    assert repository

    repository
  end
end
