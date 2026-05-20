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

defmodule EdgehogWeb.Schema.Mutation.CreateReleaseTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  alias Edgehog.Containers

  describe "createRelease mutation" do
    test "successfully creates release with valid application", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)
      version = "1.0.0"

      response =
        create_release(tenant: tenant, application_id: application_id, version: version)

      result = extract_result!(response)

      assert result["version"] == version
      assert result["application"]["id"] == application_id

      {:ok, %{id: release_id}} = AshGraphql.Resource.decode_relay_id(result["id"])
      assert Containers.fetch_release!(release_id, tenant: tenant).version == version
    end

    test "returns error when application does not exist", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)
      Ash.destroy!(application, tenant: tenant)

      response =
        create_release(tenant: tenant, application_id: application_id)

      error = extract_error!(response)

      assert [:application_id] = error.fields
      assert "invalid_attribute" == error.code
    end

    test "returns error when version is already taken", %{tenant: tenant} do
      version = "1.2.3"

      existing_release =
        [tenant: tenant, version: version]
        |> release_fixture()
        |> Ash.load!(:application)

      application_id = AshGraphql.Resource.encode_relay_id(existing_release.application)

      response =
        create_release(tenant: tenant, application_id: application_id, version: version)

      error = extract_error!(response)

      assert [:version] = error.fields
      assert "has already been taken" == error.message
    end

    test "creates a release and links existing containers", %{tenant: tenant} do
      application =
        application_fixture(tenant: tenant)

      application_id = AshGraphql.Resource.encode_relay_id(application)

      c1 = container_fixture(tenant: tenant, name: "service-a")

      document = """
      mutation CreateRelease($input: CreateReleaseInput!) {
        createRelease(input: $input) {
          result {
            containers {
              edges {
                node { id name }
              }
            }
          }
        }
      }
      """

      response =
        create_release(
          tenant: tenant,
          application_id: application_id,
          containers: [%{"id" => c1.id}],
          document: document
        )

      result = extract_result!(response)

      nodes = extract_relay_nodes(result, "containers")
      assert Enum.any?(nodes, &(&1["name"] == "service-a"))
    end

    test "cannot update existing container attributes (schema enforcement)", %{tenant: tenant} do
      application =
        application_fixture(tenant: tenant)

      application_id = AshGraphql.Resource.encode_relay_id(application)

      container = container_fixture(tenant: tenant)

      input = %{
        "application_id" => application_id,
        "version" => "1.0.1",
        "containers" => [
          %{
            "id" => container.id,
            "name" => "hacked-name"
          }
        ]
      }

      response = create_release(tenant: tenant, input: input)

      assert %{errors: [error | _]} = response
      assert error.message =~ "Unknown field"
    end

    test "links a container that already has volumes", %{tenant: tenant} do
      application =
        application_fixture(tenant: tenant)

      application_id = AshGraphql.Resource.encode_relay_id(application)

      container = container_fixture(tenant: tenant, volumes: 1)
      container_id = AshGraphql.Resource.encode_relay_id(container)

      document = """
      mutation CreateRelease($input: CreateReleaseInput!) {
        createRelease(input: $input) {
          result {
            id
            containers {
              edges {
                node {
                  id
                  containerVolumes {
                    edges { node { target } }
                  }
                }
              }
            }
          }
        }
      }
      """

      response =
        create_release(
          tenant: tenant,
          application_id: application_id,
          containers: [%{"id" => container_id}],
          document: document
        )

      result = extract_result!(response)

      [container_node] = extract_relay_nodes(result, "containers")
      volumes = extract_relay_nodes(container_node, "containerVolumes")

      assert volumes != []
    end
  end

  defp create_release(opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    input =
      if input_map = Keyword.get(opts, :input) do
        Map.put_new(input_map, "version", unique_release_version())
      else
        %{
          "version" => Keyword.get(opts, :version, unique_release_version()),
          "application_id" => Keyword.get(opts, :application_id),
          "containers" => Keyword.get(opts, :containers, [])
        }
      end

    document = Keyword.get(opts, :document, default_mutation())
    variables = %{"input" => input}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp default_mutation do
    """
    mutation CreateRelease($input: CreateReleaseInput!) {
      createRelease(input: $input) {
        result {
          id
          version
          application { id }
        }
      }
    }
    """
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createRelease" => %{
                 "result" => release
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert release

    release
  end

  defp extract_error!(result) do
    assert %{errors: [error | _]} = result
    error
  end

  defp extract_relay_nodes(parent, field_name) do
    parent
    |> Map.get(field_name, %{})
    |> Map.get("edges", [])
    |> Enum.map(& &1["node"])
  end
end
