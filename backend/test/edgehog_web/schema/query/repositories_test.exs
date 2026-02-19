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

defmodule EdgehogWeb.Schema.Query.RepositoriesTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.FilesFixtures

  describe "repositories query" do
    test "returns empty list when no repositories exist", %{tenant: tenant} do
      assert [] = [tenant: tenant] |> repositories_query() |> extract_result!()
    end

    test "returns repositories if present", %{tenant: tenant} do
      repo1 =
        repository_fixture(
          tenant: tenant,
          name: "First Repo",
          handle: "first-repo"
        )

      repo2 =
        repository_fixture(
          tenant: tenant,
          name: "Second Repo",
          handle: "second-repo"
        )

      result = [tenant: tenant] |> repositories_query() |> extract_result!()

      assert length(result) == 2
      names = Enum.map(result, & &1["name"])
      assert repo1.name in names
      assert repo2.name in names
    end

    test "does not leak repositories across tenants", %{tenant: tenant} do
      repository_fixture(tenant: tenant, name: "My Repo")

      other_tenant = Edgehog.TenantsFixtures.tenant_fixture()
      repository_fixture(tenant: other_tenant, name: "Other Repo")

      result = [tenant: tenant] |> repositories_query() |> extract_result!()

      assert length(result) == 1
      assert [%{"name" => "My Repo"}] = result
    end

    test "returns correct count in relay connection", %{tenant: tenant} do
      repository_fixture(tenant: tenant)
      repository_fixture(tenant: tenant)
      repository_fixture(tenant: tenant)

      result = repositories_query(tenant: tenant)
      assert %{data: %{"repositories" => %{"count" => 3}}} = result
    end
  end

  defp repositories_query(opts) do
    default_document = """
    query {
      repositories {
        count
        edges {
          node {
            id
            name
            handle
            description
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: %{},
      context: %{tenant: tenant}
    )
  end

  defp extract_result!(result) do
    assert %{data: %{"repositories" => %{"count" => count, "edges" => edges}}} = result
    refute :errors in Map.keys(result)

    repositories = Enum.map(edges, & &1["node"])
    assert length(repositories) == count

    repositories
  end
end
