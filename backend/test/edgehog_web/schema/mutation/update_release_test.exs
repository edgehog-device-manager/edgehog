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

defmodule EdgehogWeb.Schema.Mutation.UpdateReleaseTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Containers.Release

  describe "updateRelease mutation" do
    setup %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      c1 = container_fixture(tenant: tenant, name: "c1")
      c2 = container_fixture(tenant: tenant, name: "c2")

      release =
        release_fixture(
          tenant: tenant,
          application_id: application.id,
          version: "1.0.0",
          container_ids: [c1.id, c2.id]
        )

      id = AshGraphql.Resource.encode_relay_id(release)

      %{
        application: application,
        release: release,
        id: id,
        c1: c1,
        c2: c2
      }
    end

    test "updates release version, containers, system models, and dependencies", %{
      tenant: tenant,
      id: id,
      c2: c2
    } do
      c3 = container_fixture(tenant: tenant, name: "c3")
      sm2 = system_model_fixture(tenant: tenant, name: "SM 2")

      c2_id = AshGraphql.Resource.encode_relay_id(c2)
      c3_id = AshGraphql.Resource.encode_relay_id(c3)
      sm2_id = AshGraphql.Resource.encode_relay_id(sm2)

      response =
        update_release_mutation(
          tenant: tenant,
          id: id,
          version: "1.1.0",
          containers: [
            %{"id" => c2_id},
            %{"id" => c3_id}
          ],
          required_system_models: [
            %{"id" => sm2_id}
          ],
          container_dependencies: [
            %{"containerId" => c3_id, "dependencyId" => c2_id}
          ]
        )

      result = extract_result!(response)

      assert result["id"] == id
      assert result["version"] == "1.1.0"
      assert result["systemModels"] == [%{"id" => sm2_id, "name" => "SM 2"}]

      containers = extract_relay_nodes(result, "containers")
      assert MapSet.new(containers, & &1["id"]) == MapSet.new([c2_id, c3_id])

      assert [
               %{
                 "container" => %{"id" => ^c3_id},
                 "dependency" => %{"id" => ^c2_id}
               }
             ] = extract_relay_nodes(result, "containerDependencies")
    end

    test "replaces existing container dependencies on update", %{
      tenant: tenant,
      id: id,
      c1: c1,
      c2: c2
    } do
      c1_id = AshGraphql.Resource.encode_relay_id(c1)
      c2_id = AshGraphql.Resource.encode_relay_id(c2)

      response =
        update_release_mutation(
          tenant: tenant,
          id: id,
          containers: [%{"id" => c1_id}, %{"id" => c2_id}],
          container_dependencies: [
            %{"containerId" => c2_id, "dependencyId" => c1_id}
          ]
        )

      result = extract_result!(response)
      assert [_] = extract_relay_nodes(result, "containerDependencies")

      prune_response =
        update_release_mutation(
          tenant: tenant,
          id: id,
          containers: [%{"id" => c2_id}]
        )

      prune_result = extract_result!(prune_response)

      assert [%{"id" => ^c2_id}] = extract_relay_nodes(prune_result, "containers")
      assert [] == extract_relay_nodes(prune_result, "containerDependencies")
    end

    test "returns error when version is already taken in the same application", %{
      tenant: tenant,
      application: application,
      id: id,
      c1: c1
    } do
      release_fixture(
        tenant: tenant,
        application_id: application.id,
        version: "2.0.0",
        container_ids: [c1.id]
      )

      response =
        update_release_mutation(
          tenant: tenant,
          id: id,
          version: "2.0.0"
        )

      error = extract_error!(response)

      assert error.fields == [:version]
      assert error.message == "has already been taken"
    end

    test "returns error when the release has circular container dependencies", %{
      tenant: tenant,
      id: id,
      c1: c1,
      c2: c2
    } do
      c1_id = AshGraphql.Resource.encode_relay_id(c1)
      c2_id = AshGraphql.Resource.encode_relay_id(c2)

      response =
        update_release_mutation(
          tenant: tenant,
          id: id,
          containers: [%{"id" => c1_id}, %{"id" => c2_id}],
          container_dependencies: [
            %{"containerId" => c1_id, "dependencyId" => c2_id},
            %{"containerId" => c2_id, "dependencyId" => c1_id}
          ]
        )

      error = extract_error!(response)

      assert error.code == "invalid_attribute"
      assert error.fields == [:container_dependencies]
      assert error.message == "circular dependencies detected"
    end

    test "returns error when updating a deployed release copy", %{
      tenant: tenant,
      release: release
    } do
      device = device_fixture(tenant: tenant)

      deployment =
        deployment_fixture(tenant: tenant, device_id: device.id, release_id: release.id)

      deployed_release = Ash.get!(Release, deployment.release_id, tenant: tenant)
      deployed_release_id = AshGraphql.Resource.encode_relay_id(deployed_release)

      response =
        update_release_mutation(
          tenant: tenant,
          id: deployed_release_id,
          version: "9.9.9"
        )

      assert %{code: "not_found", fields: [:id], message: "could not be found"} =
               extract_error!(response)
    end
  end

  defp update_release_mutation(opts) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    input =
      %{
        "version" => opts[:version],
        "containers" => opts[:containers],
        "requiredSystemModels" => opts[:required_system_models],
        "containerDependencies" => opts[:container_dependencies]
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Map.new()

    variables = %{"id" => id, "input" => input}
    document = Keyword.get(opts, :document, default_document())
    context = %{tenant: tenant, actor: %{}}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp default_document do
    """
    mutation UpdateRelease($id: ID!, $input: UpdateReleaseInput!) {
      updateRelease(id: $id, input: $input) {
        result {
          id
          version
          systemModels {
            id
            name
          }
          containers {
            edges {
              node {
                id
                name
              }
            }
          }
          containerDependencies {
            edges {
              node {
                container {
                  id
                }
                dependency {
                  id
                }
              }
            }
          }
        }
      }
    }
    """
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateRelease" => %{
                 "result" => release
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert release

    release
  end

  defp extract_error!(result) do
    assert %{
             data: %{"updateRelease" => nil},
             errors: [error | _]
           } = result

    error
  end

  defp extract_relay_nodes(parent, field_name) do
    parent
    |> Map.get(field_name, %{})
    |> Map.get("edges", [])
    |> Enum.map(& &1["node"])
  end
end
