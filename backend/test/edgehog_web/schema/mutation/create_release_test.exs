#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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
    test "create release with valid application", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)
      version = "0.0.1"

      release =
        [tenant: tenant, application_id: application_id, version: version]
        |> create_release()
        |> extract_result!()

      assert release["version"] == version
      assert release["application"]["id"] == application_id
    end

    test "create release with invalid application throws error", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)
      :ok = Ash.destroy!(application, tenant: tenant)

      version = "0.0.1"

      error =
        [tenant: tenant, application_id: application_id, version: version]
        |> create_release()
        |> extract_error!()

      assert [:application_id] = error.fields
      assert "does not exist" == error.message
    end

    test "create release with already available version throws error version already taken", %{
      tenant: tenant
    } do
      version = "0.0.1"
      release = [tenant: tenant, version: version] |> release_fixture() |> Ash.load!(:application)
      application_id = AshGraphql.Resource.encode_relay_id(release.application)

      error =
        [tenant: tenant, application_id: application_id, version: version]
        |> create_release()
        |> extract_error!()

      assert [:version] = error.fields
      assert "has already been taken" == error.message
    end

    test "create a release with nested containers", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      credentials = image_credentials_fixture(tenant: tenant)
      credentials_id = AshGraphql.Resource.encode_relay_id(credentials)

      container1 = %{
        "image" => %{
          "reference" => "example/container1:latest"
        },
        "env" => ~s({"ENV_VAR":"value1"}),
        "hostname" => "container1-host",
        "networkMode" => "bridge",
        "portBindings" => [
          "8080:80"
        ],
        "privileged" => false,
        "restartPolicy" => "always",
        "extraHosts" => [
          "host1:192.168.1.100",
          "host2:192.168.1.101"
        ],
        "capAdd" => ["CAP_CHOWN"],
        "capDrop" => ["CAP_KILL"]
      }

      container2 = %{
        "image" => %{
          "reference" => "example/container2:latest",
          "imageCredentialsId" => credentials_id
        },
        "env" => ~s({"ENV_VAR":"value2"}),
        "hostname" => "container2-host",
        "networkMode" => "host",
        "portBindings" => [
          "9090:90"
        ],
        "privileged" => true,
        "restartPolicy" => "no",
        "extraHosts" => [
          "database:10.0.0.1",
          "cache:10.0.0.2",
          "api:10.0.0.3"
        ],
        "capAdd" => [
          "CAP_AUDIT_READ",
          "CAP_AUDIT_WRITE"
        ],
        "capDrop" => ["CAP_MKNOD"]
      }

      containers = [container1, container2]

      document = """
      mutation CreateRelease($input: CreateReleaseInput!) {
        createRelease(input: $input) {
          result {
            version
            application {
              id
            }
            containers {
              edges {
                node {
                  id
                  image {
                    reference
                    credentials {
                      username
                    }
                  }
                  env
                  hostname
                  networkMode
                  portBindings
                  privileged
                  restartPolicy
                  extraHosts
                  capAdd
                  capDrop
                }
              }
            }
          }
        }
      }
      """

      release =
        [
          tenant: tenant,
          application_id: application_id,
          containers: containers,
          document: document
        ]
        |> create_release()
        |> extract_result!()

      result_containers =
        release
        |> extract_containers!()
        |> Enum.map(&Map.delete(&1, "id"))

      container2 =
        Map.update!(container2, "image", fn image ->
          image
          |> Map.put("credentials", %{"username" => credentials.username})
          |> Map.delete("imageCredentialsId")
        end)

      container1 =
        Map.update!(container1, "image", fn image ->
          Map.put(image, "credentials", nil)
        end)

      containers = [container1, container2]

      assert release["application"]["id"] == application_id

      assert Enum.sort(containers) == Enum.sort(result_containers)
    end

    test "create a release with nested containers with networks", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      network = network_fixture(tenant: tenant)
      network_id = AshGraphql.Resource.encode_relay_id(network)

      container = %{
        "image" => %{
          "reference" => "example/container1:latest"
        },
        "env" => ~s({"ENV_VAR":"value1"}),
        "hostname" => "container1-host",
        "networkMode" => "bridge",
        "portBindings" => [
          "8080:80"
        ],
        "privileged" => false,
        "restartPolicy" => "always",
        "networks" => [%{"id" => network_id}]
      }

      document = """
      mutation CreateRelease($input: CreateReleaseInput!) {
        createRelease(input: $input) {
          result {
            version
            application {
              id
            }
            containers {
              edges {
                node {
                  id
                  networks {
                    edges {
                      node {
                        id
                        label
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      """

      [
        tenant: tenant,
        application_id: application_id,
        containers: [container],
        document: document
      ]
      |> create_release()
      |> extract_result!()
    end

    test "create a release with nested container and volume", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      volume = volume_fixture(tenant: tenant)
      volume_target = unique_volume_target()
      volume_id = AshGraphql.Resource.encode_relay_id(volume)

      container = %{
        "image" => %{
          "reference" => "example/container1:latest"
        },
        "env" => ~s({"ENV_VAR":"value1"}),
        "hostname" => "container1-host",
        "networkMode" => "bridge",
        "portBindings" => [
          "8080:80"
        ],
        "privileged" => false,
        "restartPolicy" => "always",
        "volumes" => [%{"id" => volume_id, "target" => volume_target}]
      }

      containers = [container]

      document = """
      mutation CreateRelease($input: CreateReleaseInput!) {
        createRelease(input: $input) {
          result {
            id
            version
            application {
              id
            }
            containers {
              edges {
                node {
                  id
                  volumes {
                    edges {
                      node {
                        id
                        label
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      """

      release =
        [
          tenant: tenant,
          application_id: application_id,
          containers: containers,
          document: document
        ]
        |> create_release()
        |> extract_result!()

      {:ok, %{id: release_id, type: :release}} =
        AshGraphql.Resource.decode_relay_id(release["id"])

      release =
        Containers.fetch_release!(release_id, tenant: tenant, load: [containers: [:volumes]])

      [container] = release.containers
      [container_volume] = container.volumes

      assert volume.id == container_volume.id
      assert volume.label == container_volume.label
    end
  end

  def create_release(opts) do
    default_document = """
    mutation CreateRelease($input: CreateReleaseInput!) {
      createRelease(input: $input) {
        result {
          version
          application {
            id
          }
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)

    default_input = %{
      "version" => unique_release_version(),
      "containers" => []
    }

    input =
      opts
      |> Keyword.take([:application_id, :version, :containers])
      |> Enum.into(default_input, fn {key, value} -> {Atom.to_string(key), value} end)

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    assert %{
             data: %{
               "createRelease" => %{
                 "result" => release
               }
             }
           } = result

    refute :errors in Map.keys(result)
    assert release != nil

    release
  end

  defp extract_error!(result) do
    assert %{
             data: %{"createRelease" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_containers!(release) do
    assert %{
             "containers" => %{
               "edges" => edges
             }
           } = release

    Enum.map(edges, fn %{"node" => container} -> container end)
  end
end
