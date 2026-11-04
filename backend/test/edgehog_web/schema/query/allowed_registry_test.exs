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

defmodule EdgehogWeb.Schema.Query.AllowedRegistryTest do
  use EdgehogWeb.GraphqlCase, async: true

  import EdgehogWeb.Schema.AllowedRegistriesFixtures

  describe "allowedRegistry query" do
    setup %{tenant: tenant} do
      allowed_registry =
        allowed_registry_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(allowed_registry)

      %{allowed_registry: allowed_registry, id: id}
    end

    test "returns allowed registry with all fields if present", %{
      tenant: tenant,
      allowed_registry: fixture,
      id: id
    } do
      allowed_registry =
        [tenant: tenant, id: id]
        |> allowed_registry_query()
        |> extract_result!()

      assert allowed_registry["id"] == id
      assert allowed_registry["registry"] == fixture.registry
    end

    test "returns allowed registry when registry is an IPv4 address", %{tenant: tenant} do
      fixture = allowed_registry_fixture(tenant: tenant, registry: "192.168.1.1")
      id = AshGraphql.Resource.encode_relay_id(fixture)

      allowed_registry =
        [tenant: tenant, id: id]
        |> allowed_registry_query()
        |> extract_result!()

      assert allowed_registry["id"] == id
      assert allowed_registry["registry"] == "192.168.1.1"
    end

    test "returns allowed registry when registry is an IPv6 address", %{tenant: tenant} do
      fixture = allowed_registry_fixture(tenant: tenant, registry: "2001:db8::1")
      id = AshGraphql.Resource.encode_relay_id(fixture)

      allowed_registry =
        [tenant: tenant, id: id]
        |> allowed_registry_query()
        |> extract_result!()

      assert allowed_registry["id"] == id
      assert allowed_registry["registry"] == "2001:db8::1"
    end

    test "returns allowed registry with custom document selecting only specific fields", %{
      tenant: tenant,
      allowed_registry: fixture,
      id: id
    } do
      document = """
      query ($id: ID!) {
        allowedRegistry(id: $id) {
          registry
        }
      }
      """

      allowed_registry =
        [tenant: tenant, id: id, document: document]
        |> allowed_registry_query()
        |> extract_result!()

      assert allowed_registry == %{"registry" => fixture.registry}
      refute Map.has_key?(allowed_registry, "id")
    end

    test "returns nil if non existing", %{tenant: tenant} do
      id = non_existing_allowed_registry_id(tenant)

      result = allowed_registry_query(tenant: tenant, id: id)

      assert result == %{data: %{"allowedRegistry" => nil}}
    end

    test "returns nil for non existing relay ID", %{tenant: tenant} do
      id =
        AshGraphql.Resource.encode_relay_id(%Edgehog.Containers.AllowedRegistry{
          id: Ash.UUID.generate()
        })

      result = allowed_registry_query(tenant: tenant, id: id)

      assert result == %{data: %{"allowedRegistry" => nil}}
    end

    test "returns nil for allowed registry belonging to another tenant", %{id: id} do
      other_tenant = Edgehog.TenantsFixtures.tenant_fixture()

      result = allowed_registry_query(tenant: other_tenant, id: id)

      assert result == %{data: %{"allowedRegistry" => nil}}
    end
  end

  defp allowed_registry_query(opts) do
    default_document = """
    query ($id: ID!) {
      allowedRegistry(id: $id) {
        id
        registry
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables =
      opts
      |> Keyword.get(:extra_variables, %{})
      |> Map.put("id", id)

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "allowedRegistry" => allowed_registry
             }
           } = result

    refute Map.get(result, :errors)

    assert allowed_registry

    allowed_registry
  end

  defp non_existing_allowed_registry_id(tenant) do
    fixture = allowed_registry_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture)

    id
  end
end
