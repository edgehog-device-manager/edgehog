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

defmodule EdgehogWeb.Schema.Query.RepositoryTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.FilesFixtures

  describe "repository query" do
    test "returns a repository by ID", %{tenant: tenant} do
      fixture =
        repository_fixture(
          tenant: tenant,
          name: "My Repo",
          handle: "my-repo",
          description: "A test repository"
        )

      id = AshGraphql.Resource.encode_relay_id(fixture)

      repository =
        [tenant: tenant, id: id]
        |> repository_query()
        |> extract_result!()

      assert repository["id"] == id
      assert repository["name"] == "My Repo"
      assert repository["handle"] == "my-repo"
      assert repository["description"] == "A test repository"
    end

    test "returns repository without description", %{tenant: tenant} do
      fixture = repository_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(fixture)

      repository =
        [tenant: tenant, id: id]
        |> repository_query()
        |> extract_result!()

      assert repository["name"] == fixture.name
      assert repository["handle"] == fixture.handle
      assert is_nil(repository["description"])
    end

    test "returns nil for non-existing repository", %{tenant: tenant} do
      id = non_existing_repository_id(tenant)
      result = repository_query(tenant: tenant, id: id)
      assert result == %{data: %{"repository" => nil}}
    end

    test "returns associated files", %{tenant: tenant} do
      repo = repository_fixture(tenant: tenant)
      file = file_fixture(tenant: tenant, repository_id: repo.id, name: "firmware.bin")
      _other_file = file_fixture(tenant: tenant, name: "other.bin")

      repo_id = AshGraphql.Resource.encode_relay_id(repo)
      file_id = AshGraphql.Resource.encode_relay_id(file)

      document = """
      query ($id: ID!) {
        repository(id: $id) {
          id
          name
          files {
            id
            name
          }
        }
      }
      """

      repository =
        [tenant: tenant, id: repo_id, document: document]
        |> repository_query()
        |> extract_result!()

      assert [returned_file] = repository["files"]
      assert returned_file["id"] == file_id
      assert returned_file["name"] == "firmware.bin"
    end
  end

  defp non_existing_repository_id(tenant) do
    fixture = repository_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture, tenant: tenant)
    id
  end

  defp repository_query(opts) do
    default_document = """
    query ($id: ID!) {
      repository(id: $id) {
        id
        name
        handle
        description
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables = %{"id" => id}
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant}
    )
  end

  defp extract_result!(result) do
    assert %{data: %{"repository" => repository}} = result
    refute Map.get(result, :errors)
    assert repository

    repository
  end
end
