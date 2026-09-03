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

defmodule EdgehogWeb.Schema.Mutation.DeleteContainerTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  require Ash.Query

  describe "deleteContainer mutation" do
    test "successfully deletes a container if nothing reference it.", %{tenant: tenant} do
      container = container_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(container)

      res =
        [tenant: tenant, id: id]
        |> delete_container()
        |> extract_result!()

      assert res["id"] == id
      assert res["name"] == container.name

      db_containers =
        Edgehog.Containers.Container
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(id: container.id)
        |> Ash.read!(tenant: tenant)

      assert db_containers == []
    end

    test "refuses to delete a container if there is a matching release", %{tenant: tenant} do
      container = container_fixture(tenant: tenant)

      release_fixture(tenant: tenant, container_ids: [container.id])

      id = AshGraphql.Resource.encode_relay_id(container)

      [tenant: tenant, id: id]
      |> delete_container()
      |> extract_error!()

      [db_container] =
        Edgehog.Containers.Container
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(id: container.id)
        |> Ash.read!(tenant: tenant)

      assert db_container.id == container.id
      assert db_container.name == container.name
    end

    test "refuses to delete a container if there is a matching container deployment", %{
      tenant: tenant
    } do
      container = container_fixture(tenant: tenant)

      container_deployment_fixture(tenant: tenant, container_id: container.id)

      id = AshGraphql.Resource.encode_relay_id(container)

      [tenant: tenant, id: id]
      |> delete_container()
      |> extract_error!()

      [db_container] =
        Edgehog.Containers.Container
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(id: container.id)
        |> Ash.read!(tenant: tenant)

      assert db_container.id == container.id
      assert db_container.name == container.name
    end

    test "refuses to delete a container if there is a matching container deployment and release",
         %{
           tenant: tenant
         } do
      container = container_fixture(tenant: tenant)

      release_fixture(tenant: tenant, container_ids: [container.id])
      container_deployment_fixture(tenant: tenant, container_id: container.id)

      id = AshGraphql.Resource.encode_relay_id(container)

      [tenant: tenant, id: id]
      |> delete_container()
      |> extract_error!()

      [db_container] =
        Edgehog.Containers.Container
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(id: container.id)
        |> Ash.read!(tenant: tenant)

      assert db_container.id == container.id
      assert db_container.name == container.name
    end
  end

  defp delete_container(opts) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    document = Keyword.get(opts, :document, _default_mutation())
    variables = %{"id" => id}
    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp _default_mutation do
    """
    mutation DeleteContainer($id: ID!) {
      deleteContainer(id: $id) {
        result {
          id
          name
        }
      }
    }
    """
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteContainer" => %{
                 "result" => container
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert container

    container
  end

  defp extract_error!(result) do
    assert %{
             data: %{
               "deleteContainer" => nil
             },
             errors: [error]
           } = result

    error
  end
end
