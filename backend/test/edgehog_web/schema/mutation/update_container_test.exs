#
# This file is part of Edgehog.
#
# Copyright 2024 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.UpdateContainerTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  alias Edgehog.Containers

  describe "updateContainer mutation" do
    test "successfully updates the container name", %{tenant: tenant} do
      container = container_fixture(tenant: tenant, name: "old-name")
      container_id = AshGraphql.Resource.encode_relay_id(container)
      new_name = "new-shiny-name"

      document = """
      mutation UpdateContainer($id: ID!, $input: UpdateContainerInput!) {
        updateContainer(id: $id, input: $input) {
          result {
            id
            name
          }
        }
      }
      """

      input = %{"name" => new_name}

      response =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"id" => container_id, "input" => input},
          context: %{tenant: tenant}
        )

      result = extract_result!(response)

      assert result["name"] == new_name

      db_container = Containers.fetch_container!(container.id, tenant: tenant)
      assert db_container.name == new_name
    end

    test "fails to update fields not permitted by the action", %{tenant: tenant} do
      container = container_fixture(tenant: tenant, name: "persistent-name")
      container_id = AshGraphql.Resource.encode_relay_id(container)

      document = """
      mutation UpdateContainer($id: ID!, $input: UpdateContainerInput!) {
        updateContainer(id: $id, input: $input) {
          result {
            id
            name
          }
        }
      }
      """

      input = %{
        "name" => "trying-to-change-policy",
        "restartPolicy" => "ALWAYS"
      }

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"id" => container_id, "input" => input},
          context: %{tenant: tenant}
        )

      assert %{errors: [%{message: message}]} = result

      assert String.contains?(message, "Unknown field") or
               String.contains?(message, "In field \"restartPolicy\"")
    end

    test "returns an error when the container does not exist", %{tenant: tenant} do
      bad_uuid = Ecto.UUID.generate()
      bad_id = Base.encode64("Container:#{bad_uuid}")

      document = """
      mutation UpdateContainer($id: ID!, $input: UpdateContainerInput!) {
        updateContainer(id: $id, input: $input) {
          result { id }
        }
      }
      """

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"id" => bad_id, "input" => %{"name" => "wont-work"}},
          context: %{tenant: tenant}
        )

      assert %{errors: [%{code: "invalid_primary_key"}]} = result
    end
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateContainer" => %{
                 "result" => container
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert container

    container
  end
end
