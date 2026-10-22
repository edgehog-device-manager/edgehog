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

      container = container_fixture(tenant: tenant, name: "original-name")

      document = """
      mutation CreateRelease($input: CreateReleaseInput!) {
        createRelease(input: $input) {
          result {
            containers {
              edges { node { id name } }
            }
          }
        }
      }
      """

      input = %{
        "application_id" => application_id,
        "containers" => [
          %{
            "id" => AshGraphql.Resource.encode_relay_id(container),
            "name" => "hacked-name"
          }
        ]
      }

      response = create_release(tenant: tenant, input: input, document: document)

      result = extract_result!(response)

      # referencing an existing container ignores any provided attributes
      [node] = extract_relay_nodes(result, "containers")
      assert node["id"] == AshGraphql.Resource.encode_relay_id(container)
      assert node["name"] == "original-name"
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

    test "links a container that already has dependencies", %{tenant: tenant} do
      application =
        application_fixture(tenant: tenant)

      application_id = AshGraphql.Resource.encode_relay_id(application)

      c1 = container_fixture(tenant: tenant, name: "service-a")
      c2 = container_fixture(tenant: tenant, name: "service-b")

      document = """
      mutation CreateRelease($input: CreateReleaseInput!) {
        createRelease(input: $input) {
          result {
            containers {
              edges {
                node {
                  id
                }
              }
            }
            containerDependencies {
              edges {
                node {
                  container {
                    name
                  }
                  dependency {
                    name
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
          containers: [
            %{"id" => AshGraphql.Resource.encode_relay_id(c1)},
            %{"id" => AshGraphql.Resource.encode_relay_id(c2)}
          ],
          container_dependencies: [
            %{
              "container_id" => AshGraphql.Resource.encode_relay_id(c1),
              "dependency_id" => AshGraphql.Resource.encode_relay_id(c2)
            }
          ],
          document: document
        )

      result = extract_result!(response)

      dependencies = extract_relay_nodes(result, "containerDependencies")

      assert Enum.any?(dependencies, fn dep ->
               dep["dependency"]["name"] == "service-b" and
                 dep["container"]["name"] == "service-a"
             end)
    end

    test "returns error when the release has circular container dependencies", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      c1 = container_fixture(tenant: tenant, name: "service-a")
      c2 = container_fixture(tenant: tenant, name: "service-b")

      response =
        create_release(
          tenant: tenant,
          application_id: application_id,
          containers: [
            %{"id" => AshGraphql.Resource.encode_relay_id(c1)},
            %{"id" => AshGraphql.Resource.encode_relay_id(c2)}
          ],
          container_dependencies: [
            %{
              "container_id" => AshGraphql.Resource.encode_relay_id(c1),
              "dependency_id" => AshGraphql.Resource.encode_relay_id(c2)
            },
            %{
              "container_id" => AshGraphql.Resource.encode_relay_id(c2),
              "dependency_id" => AshGraphql.Resource.encode_relay_id(c1)
            }
          ]
        )

      error = extract_error!(response)

      assert error.code == "invalid_argument"
      assert error.fields == [:container_dependencies]
      assert error.message == "circular dependencies detected"
    end
  end

  describe "createRelease mutation with inline containers" do
    test "creates a release with inline containers and dependencies by name", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      document = """
      mutation CreateRelease($input: CreateReleaseInput!) {
        createRelease(input: $input) {
          result {
            id
            containers {
              edges { node { id name restartPolicy } }
            }
            containerDependencies {
              edges { node { container { name } dependency { name } } }
            }
          }
        }
      }
      """

      input = %{
        "application_id" => application_id,
        "containers" => [
          %{
            "name" => "backend",
            "restart_policy" => "ALWAYS",
            "image" => %{"reference" => unique_image_reference()},
            "depends_on" => ["database"]
          },
          %{
            "name" => "database",
            "image" => %{"reference" => unique_image_reference()}
          }
        ]
      }

      response =
        create_release(
          tenant: tenant,
          application_id: application_id,
          input: input,
          document: document
        )

      result = extract_result!(response)

      nodes = extract_relay_nodes(result, "containers")
      names = nodes |> Enum.map(& &1["name"]) |> Enum.sort()
      assert names == ["backend", "database"]

      backend = Enum.find(nodes, &(&1["name"] == "backend"))
      assert backend["restartPolicy"] == "always"

      [dependency] = extract_relay_nodes(result, "containerDependencies")
      assert dependency["container"]["name"] == "backend"
      assert dependency["dependency"]["name"] == "database"

      # containers must be persisted and linked to the release
      {:ok, %{id: release_id}} = AshGraphql.Resource.decode_relay_id(result["id"])

      release =
        release_id
        |> Containers.fetch_release!(tenant: tenant)
        |> Ash.load!(:containers)

      assert length(release.containers) == 2
    end

    test "creates inline containers with nested networks, volumes and device mappings", %{
      tenant: tenant
    } do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      network = network_fixture(tenant: tenant)
      volume = volume_fixture(tenant: tenant)
      image_credentials = image_credentials_fixture(tenant: tenant)

      document = """
      mutation CreateRelease($input: CreateReleaseInput!) {
        createRelease(input: $input) {
          result {
            containers {
              edges {
                node {
                  name
                  networks { edges { node { id } } }
                  containerVolumes { edges { node { target } } }
                  deviceMappings { edges { node { pathOnHost pathInContainer } } }
                }
              }
            }
          }
        }
      }
      """

      input = %{
        "application_id" => application_id,
        "containers" => [
          %{
            "name" => "worker",
            "image" => %{
              "reference" => unique_image_reference(),
              "image_credentials_id" => AshGraphql.Resource.encode_relay_id(image_credentials)
            },
            "networks" => [%{"id" => AshGraphql.Resource.encode_relay_id(network)}],
            "volumes" => [
              %{
                "id" => AshGraphql.Resource.encode_relay_id(volume),
                "target" => "/var/data"
              }
            ],
            "device_mappings" => [
              %{
                "path_on_host" => "/dev/ttyUSB0",
                "path_in_container" => "/dev/ttyUSB0",
                "cgroup_permissions" => "rwm"
              }
            ]
          }
        ]
      }

      response =
        create_release(
          tenant: tenant,
          application_id: application_id,
          input: input,
          document: document
        )

      result = extract_result!(response)

      [worker] = extract_relay_nodes(result, "containers")

      assert worker["name"] == "worker"
      assert [%{"id" => _}] = extract_relay_nodes(worker, "networks")
      assert [%{"target" => "/var/data"}] = extract_relay_nodes(worker, "containerVolumes")

      assert [%{"pathOnHost" => "/dev/ttyUSB0", "pathInContainer" => "/dev/ttyUSB0"}] =
               extract_relay_nodes(worker, "deviceMappings")
    end

    test "resolves depends_on against existing containers linked by id", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      database = container_fixture(tenant: tenant, name: "database")

      document = """
      mutation CreateRelease($input: CreateReleaseInput!) {
        createRelease(input: $input) {
          result {
            containerDependencies {
              edges { node { container { name } dependency { id } } }
            }
          }
        }
      }
      """

      input = %{
        "application_id" => application_id,
        "containers" => [
          %{
            "name" => "backend",
            "image" => %{"reference" => unique_image_reference()},
            "depends_on" => ["database"]
          },
          %{"id" => AshGraphql.Resource.encode_relay_id(database)}
        ]
      }

      response =
        create_release(
          tenant: tenant,
          application_id: application_id,
          input: input,
          document: document
        )

      result = extract_result!(response)

      [dependency] = extract_relay_nodes(result, "containerDependencies")
      assert dependency["container"]["name"] == "backend"
      assert dependency["dependency"]["id"] == AshGraphql.Resource.encode_relay_id(database)
    end

    test "returns error when depends_on references an unknown container", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      input = %{
        "application_id" => application_id,
        "containers" => [
          %{
            "name" => "backend",
            "image" => %{"reference" => unique_image_reference()},
            "depends_on" => ["nonexistent"]
          }
        ]
      }

      response =
        create_release(tenant: tenant, application_id: application_id, input: input)

      error = extract_error!(response)

      assert error.code == "invalid_argument"
      assert [:containers] = error.fields
      assert error.message =~ "nonexistent"
    end

    test "returns error when inline containers have duplicate names", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      input = %{
        "application_id" => application_id,
        "containers" => [
          %{"name" => "app", "image" => %{"reference" => unique_image_reference()}},
          %{"name" => "app", "image" => %{"reference" => unique_image_reference()}},
          %{
            "name" => "frontend",
            "image" => %{"reference" => unique_image_reference()},
            "depends_on" => ["app"]
          }
        ]
      }

      response =
        create_release(tenant: tenant, application_id: application_id, input: input)

      error = extract_error!(response)

      assert error.code == "invalid_argument"
      assert [:containers] = error.fields
      assert error.message =~ "duplicate container names"
    end

    test "returns error when inline depends_on has circular dependencies", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      input = %{
        "application_id" => application_id,
        "containers" => [
          %{
            "name" => "a",
            "image" => %{"reference" => unique_image_reference()},
            "depends_on" => ["b"]
          },
          %{
            "name" => "b",
            "image" => %{"reference" => unique_image_reference()},
            "depends_on" => ["a"]
          }
        ]
      }

      response =
        create_release(tenant: tenant, application_id: application_id, input: input)

      error = extract_error!(response)

      assert error.code == "invalid_argument"
      assert error.fields == [:container_dependencies]
      assert error.message == "circular dependencies detected"
    end

    test "rolls back created containers when dependency resolution fails", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      input = %{
        "application_id" => application_id,
        "containers" => [
          %{
            "name" => "doomed-container",
            "image" => %{"reference" => unique_image_reference()},
            "depends_on" => ["ghost"]
          }
        ]
      }

      response =
        create_release(tenant: tenant, application_id: application_id, input: input)

      assert %{errors: [_error | _]} = response

      require Ash.Query

      no_container? =
        Edgehog.Containers.Container
        |> Ash.Query.filter(name: "doomed-container")
        |> Ash.read_one!(tenant: tenant)
        |> is_nil()

      assert no_container?
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
          "containers" => Keyword.get(opts, :containers, []),
          "container_dependencies" => Keyword.get(opts, :container_dependencies, [])
        }
      end

    document = Keyword.get(opts, :document, default_mutation())
    variables = %{"input" => input}

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
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
