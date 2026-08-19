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

defmodule EdgehogWeb.Schema.Mutation.CreateContainerTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers

  require Ash.Query

  describe "createContainer mutation" do
    test "successfully creates a container and links an image via reference and credentials", %{
      tenant: tenant
    } do
      credentials = image_credentials_fixture(tenant: tenant)
      credentials_id = AshGraphql.Resource.encode_relay_id(credentials)

      reference = "ghcr.io/my-repo/my-image:latest"

      _image =
        image_fixture(tenant: tenant, reference: reference, image_credentials_id: credentials.id)

      input = %{
        "name" => "worker-node",
        "image" => %{
          "reference" => reference,
          "image_credentials_id" => credentials_id
        },
        "restartPolicy" => "ALWAYS"
      }

      response =
        create_container(tenant: tenant, input: input)

      result = extract_result!(response)

      assert result["name"] == "worker-node"

      {:ok, %{id: container_id}} = AshGraphql.Resource.decode_relay_id(result["id"])
      db_container = Containers.fetch_container!(container_id, tenant: tenant, load: :image)

      assert db_container.image.reference == reference
    end

    test "fails when container name already exists (unique constraint)", %{tenant: tenant} do
      existing = container_fixture(tenant: tenant, name: "duplicate-me")
      image = image_fixture(tenant: tenant)

      input = %{
        "name" => existing.name,
        "image" => %{"reference" => image.reference}
      }

      result = create_container(tenant: tenant, input: input)

      assert %{
               errors: [
                 %{code: "invalid_attribute", message: "has already been taken", fields: [:name]}
               ]
             } = result
    end

    test "creates a container with nested networks and volumes", %{tenant: tenant} do
      image = image_fixture(tenant: tenant)
      network = network_fixture(tenant: tenant)
      network_id = AshGraphql.Resource.encode_relay_id(network)

      volume = volume_fixture(tenant: tenant, label: "data-storage")
      volume_id = AshGraphql.Resource.encode_relay_id(volume)

      document = """
      mutation CreateContainer($input: CreateContainerInput!) {
        createContainer(input: $input) {
          result {
            id
            networks {
              edges { node { id } }
            }
            containerVolumes {
              edges {
                node {
                  target
                  volume { id }
                }
              }
            }
          }
        }
      }
      """

      input = %{
        "name" => "db-service",
        "image" => %{"reference" => image.reference},
        "networks" => [%{"id" => network_id}],
        "volumes" => [
          %{
            "target" => "/var/lib/mysql",
            "id" => volume_id
          }
        ]
      }

      response =
        create_container(tenant: tenant, input: input, document: document)

      result = extract_result!(response)

      networks = extract_relay_nodes(result, "networks")
      assert Enum.any?(networks, &(&1["id"] == network_id))

      volumes = extract_relay_nodes(result, "containerVolumes")
      assert Enum.any?(volumes, &(&1["target"] == "/var/lib/mysql"))
      assert Enum.any?(volumes, &(&1["volume"]["id"] == volume_id))
    end

    test "fails if the nested image cannot be found", %{tenant: tenant} do
      creds = image_credentials_fixture(tenant: tenant)
      creds_id = AshGraphql.Resource.encode_relay_id(creds)
      Ash.destroy!(creds, tenant: tenant)

      input = %{
        "name" => "fail-container",
        "image" => %{
          "reference" => "non-existent-reference",
          "image_credentials_id" => creds_id
        }
      }

      result = create_container(tenant: tenant, input: input)

      assert %{errors: [_ | _]} = result
    end

    test "successfully creates container with environment variables", %{tenant: tenant} do
      image = image_fixture(tenant: tenant)

      env_vars = [
        %{"key" => "DEBUG", "value" => "true"},
        %{"key" => "PORT", "value" => "8080"}
      ]

      input = %{
        "name" => "env-container",
        "image" => %{"reference" => image.reference},
        "env" => env_vars
      }

      response = create_container(tenant: tenant, input: input)

      result = extract_result!(response)

      {:ok, %{id: container_id}} = AshGraphql.Resource.decode_relay_id(result["id"])
      db_container = Containers.fetch_container!(container_id, tenant: tenant)

      assert Enum.any?(db_container.env, &(&1.key == "DEBUG" and &1.value == "true"))
    end

    test "creates a container with nested device mappings", %{tenant: tenant} do
      image = image_fixture(tenant: tenant)

      input = %{
        "name" => "device-container",
        "image" => %{"reference" => image.reference},
        "device_mappings" => [
          %{
            "path_on_host" => "/dev/ttyUSB0",
            "path_in_container" => "/dev/ttyUSB0",
            "cgroup_permissions" => "rwm"
          }
        ]
      }

      document = """
      mutation CreateContainer($input: CreateContainerInput!) {
        createContainer(input: $input) {
          result {
            id
            deviceMappings {
              edges {
                node {
                  pathOnHost
                  pathInContainer
                }
              }
            }
          }
        }
      }
      """

      response =
        create_container(tenant: tenant, input: input, document: document)

      result = extract_result!(response)

      mappings = extract_relay_nodes(result, "deviceMappings")
      assert length(mappings) == 1
      assert hd(mappings)["pathOnHost"] == "/dev/ttyUSB0"
    end

    test "creates a container with nested device requests", %{tenant: tenant} do
      image = image_fixture(tenant: tenant)

      input = %{
        "name" => "device-container",
        "image" => %{"reference" => image.reference},
        "device_requests" => [
          %{
            "driver" => "driver",
            "count" => 2,
            "capabilities" => [["gpu", "compute"]],
            "options" =>
              Jason.encode!(%{
                "key1" => "value1",
                "key2" => "value2"
              })
          }
        ]
      }

      document = """
      mutation CreateContainer($input: CreateContainerInput!) {
        createContainer(input: $input) {
          result {
            id
            deviceRequests {
              edges {
                node {
                  driver
                  count
                  capabilities
                  options
                }
              }
            }
          }
        }
      }
      """

      response =
        create_container(tenant: tenant, input: input, document: document)

      result = extract_result!(response)

      {:ok, %{id: container_id}} = AshGraphql.Resource.decode_relay_id(result["id"])

      db_container =
        Containers.fetch_container!(container_id,
          tenant: tenant,
          load: [device_requests: [:capabilities]]
        )

      assert [
               %Edgehog.Containers.DeviceRequest{
                 driver: "driver",
                 capabilities: [["gpu", "compute"]],
                 count: 2,
                 options: %{"key1" => "value1", "key2" => "value2"}
               }
             ] = db_container.device_requests
    end

    test "fails when cpu_period is out of constraints", %{tenant: tenant} do
      image = image_fixture(tenant: tenant)

      input = %{
        "name" => "cpu-fail-container",
        "image" => %{"reference" => image.reference},
        "cpu_period" => 2_000_000
      }

      result = create_container(tenant: tenant, input: input)

      assert %{errors: [%{code: "invalid_attribute", fields: [:cpu_period]}]} = result
    end

    test "fails and rolls back when one of the volumes is invalid", %{tenant: tenant} do
      image = image_fixture(tenant: tenant)
      bad_uuid = Ecto.UUID.generate()
      bad_id = Base.encode64("Volume:#{bad_uuid}")

      input = %{
        "name" => "failing-rollback-test",
        "image" => %{"reference" => image.reference},
        "volumes" => [%{"target" => "/data", "id" => bad_id}]
      }

      result = create_container(tenant: tenant, input: input)

      assert %{errors: [%{code: "not_found"}]} = result

      no_container? =
        Edgehog.Containers.Container
        |> Ash.Query.filter(name: "failing-rollback-test")
        |> Ash.read_one!(tenant: tenant)
        |> is_nil()

      assert no_container?
    end

    test "returns a validation error for invalid restart policy", %{tenant: tenant} do
      image = image_fixture(tenant: tenant)

      input = %{
        "name" => "bad-policy-container",
        "image" => %{"reference" => image.reference},
        "restartPolicy" => "NOT_A_REAL_POLICY"
      }

      result = create_container(tenant: tenant, input: input)

      assert %{errors: [%{message: message}]} = result
      assert message == "is invalid"
    end

    test "successfully links multiple existing networks", %{tenant: tenant} do
      image = image_fixture(tenant: tenant)
      n1 = network_fixture(tenant: tenant)
      n2 = network_fixture(tenant: tenant)

      input = %{
        "name" => "multi-net",
        "image" => %{"reference" => image.reference},
        "networks" => [
          %{"id" => AshGraphql.Resource.encode_relay_id(n1)},
          %{"id" => AshGraphql.Resource.encode_relay_id(n2)}
        ]
      }

      document = """
      mutation CreateContainer($input: CreateContainerInput!) {
        createContainer(input: $input) {
          result {
            networks { edges { node { id } } }
          }
        }
      }
      """

      response =
        create_container(tenant: tenant, input: input, document: document)

      result = extract_result!(response)

      network_ids = result |> extract_relay_nodes("networks") |> Enum.map(& &1["id"])

      assert length(network_ids) == 2
      assert AshGraphql.Resource.encode_relay_id(n1) in network_ids
    end

    test "cannot link a network belonging to a different tenant", %{tenant: tenant} do
      other_tenant = tenant_fixture()
      other_network = network_fixture(tenant: other_tenant)
      other_network_id = AshGraphql.Resource.encode_relay_id(other_network)

      image = image_fixture(tenant: tenant)

      input = %{
        "name" => "cross-tenant-attempt",
        "image" => %{"reference" => image.reference},
        "networks" => [%{"id" => other_network_id}]
      }

      result = create_container(tenant: tenant, input: input)

      assert %{errors: [%{code: "not_found"}]} = result
    end
  end

  defp create_container(opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    input = Keyword.get(opts, :input, %{})

    document = Keyword.get(opts, :document, _default_mutation())
    variables = %{"input" => input}

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp _default_mutation do
    """
    mutation CreateContainer($input: CreateContainerInput!) {
      createContainer(input: $input) {
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
               "createContainer" => %{
                 "result" => container
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert container

    container
  end

  defp extract_relay_nodes(parent, field_name) do
    parent
    |> Map.get(field_name, %{})
    |> Map.get("edges", [])
    |> Enum.map(& &1["node"])
  end
end
