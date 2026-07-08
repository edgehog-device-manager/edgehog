# This file is part of Edgehog.
#
# Copyright 2021-2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.DeployReleaseTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Containers.Deployment

  test "deployRelease creates the deployment on the device", %{tenant: tenant} do
    containers = 3
    # one volume per container
    volumes_per_container = 1
    volume_target = "/var/local/fixture#{System.unique_integer([:positive])}"

    network = network_fixture(tenant: tenant)
    device_mapping = device_mapping_fixture(tenant: tenant)
    device_request = device_request_fixture(tenant: tenant)

    container_params = [
      volumes: volumes_per_container,
      volume_target: volume_target,
      networks: [network.id],
      device_mappings: [device_mapping.id],
      device_requests: [device_request.id]
    ]

    device = device_fixture(tenant: tenant)

    release =
      release_fixture(tenant: tenant, containers: containers, container_params: container_params)

    expect(Deployment.Supervisor, :supervise, fn _, _ ->
      # We just expect the container supervisor to be started, the container supervisor tests are separate
      :ok
    end)

    [
      tenant: tenant,
      release_id: AshGraphql.Resource.encode_relay_id(release),
      device_id: AshGraphql.Resource.encode_relay_id(device)
    ]
    |> deploy_release_mutation()
    |> extract_result!()
  end

  test "deployRelease sends containers in order depending on their dependencies", %{
    tenant: tenant
  } do
    container_1 = container_fixture(tenant: tenant)
    container_2 = container_fixture(tenant: tenant)
    container_3 = container_fixture(tenant: tenant)

    container_dependencies = [
      %{
        "container_id" => container_2.id,
        "dependency_id" => container_3.id
      },
      %{
        "container_id" => container_3.id,
        "dependency_id" => container_1.id
      }
    ]

    device = device_fixture(tenant: tenant)

    release =
      release_fixture(
        tenant: tenant,
        container_ids: [container_1.id, container_2.id, container_3.id],
        container_dependencies: container_dependencies
      )

    ordered_containers = [container_1.id, container_3.id, container_2.id]

    expect(Deployment.Supervisor, :supervise, fn deployment, _ ->
      {:ok, ids} =
        deployment
        |> Ash.load!(release: [:containers, :container_dependencies])
        |> sort_containers()

      assert ids == ordered_containers

      :ok
    end)

    [
      tenant: tenant,
      release_id: AshGraphql.Resource.encode_relay_id(release),
      device_id: AshGraphql.Resource.encode_relay_id(device)
    ]
    |> deploy_release_mutation()
    |> extract_result!()
  end

  # TODO: this fails as circualr dependencies are checked in another process.
  @tag :skip
  test "deployRelease returns an error if the release has a circular dependency", %{
    tenant: tenant
  } do
    container_1 = container_fixture(tenant: tenant)
    container_2 = container_fixture(tenant: tenant)

    container_dependencies = [
      %{
        "container_id" => container_1.id,
        "dependency_id" => container_2.id
      },
      %{
        "container_id" => container_2.id,
        "dependency_id" => container_1.id
      }
    ]

    device = device_fixture(tenant: tenant)

    release =
      release_fixture(
        tenant: tenant,
        container_ids: [container_1.id, container_2.id],
        container_dependencies: container_dependencies
      )

    error =
      [
        tenant: tenant,
        release_id: AshGraphql.Resource.encode_relay_id(release),
        device_id: AshGraphql.Resource.encode_relay_id(device)
      ]
      |> deploy_release_mutation()
      |> extract_error!()

    assert %{
             code: "invalid_changes",
             message: "Invalid deployment: circular dependencies detected"
           } = error
  end

  test "deployRelease returns an error if the application's release system model does not match the device's system model",
       %{tenant: tenant} do
    part_number =
      [tenant: tenant]
      |> system_model_fixture()
      |> Map.fetch!(:part_numbers)
      |> Enum.random()
      |> Map.fetch!(:part_number)

    system_model_2 = system_model_fixture(tenant: tenant)

    device = device_fixture(tenant: tenant, part_number: part_number)

    application = application_fixture(tenant: tenant)

    release =
      release_fixture(
        tenant: tenant,
        application_id: application.id,
        system_models: [system_model_2]
      )

    error =
      [
        tenant: tenant,
        release_id: AshGraphql.Resource.encode_relay_id(release),
        device_id: AshGraphql.Resource.encode_relay_id(device)
      ]
      |> deploy_release_mutation()
      |> extract_error!()

    assert error.code == "invalid_argument"
    assert error.fields == [:system_model]
  end

  test "deployRelease allows creating a deployment when device system model and application's release system model match",
       %{tenant: tenant} do
    system_model = system_model_fixture(tenant: tenant)

    part_number =
      system_model
      |> Map.fetch!(:part_numbers)
      |> Enum.random()
      |> Map.fetch!(:part_number)

    device = device_fixture(tenant: tenant, part_number: part_number)

    application = application_fixture(tenant: tenant)

    release =
      release_fixture(
        tenant: tenant,
        application_id: application.id,
        system_models: [system_model]
      )

    expect(Deployment.Supervisor, :supervise, fn _, _ ->
      # We just expect the container supervisor to be started, the container supervisor tests are separate
      :ok
    end)

    [
      tenant: tenant,
      release_id: AshGraphql.Resource.encode_relay_id(release),
      device_id: AshGraphql.Resource.encode_relay_id(device)
    ]
    |> deploy_release_mutation()
    |> extract_result!()
  end

  defp deploy_release_mutation(opts) do
    default_document = """
    mutation DeployRelease($input: DeployReleaseInput!) {
      deployRelease(input: $input) {
        result {
          id
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        [tenant: tenant]
        |> device_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {release_id, opts} =
      Keyword.pop_lazy(opts, :release_id, fn ->
        [tenant: tenant]
        |> release_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    input = %{
      "deviceId" => device_id,
      "releaseId" => release_id
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{data: %{"deployRelease" => %{"result" => deployment}}} = result

    assert deployment

    deployment
  end

  defp extract_error!(result) do
    assert %{
             data: %{"deployRelease" => nil},
             errors: [error]
           } = result

    error
  end

  # NOTE: coped from `send_create_deployment`, builds the dependency graph from
  # dependencies spec
  defp sort_containers(deployment) do
    release = deployment.release

    dependency_graph = build_graph(release.containers, release.container_dependencies)

    case Graph.topsort(dependency_graph) do
      false ->
        {:error, "Invalid deployment: circular dependencies detected"}

      ids ->
        {:ok, ids}
    end
  end

  defp build_graph(containers, dependencies) do
    graph =
      Enum.reduce(containers, Graph.new(), fn container, graph ->
        Graph.add_vertex(graph, container.id)
      end)

    Enum.reduce(dependencies, graph, fn dep, graph ->
      Graph.add_edge(graph, dep.dependency_id, dep.container_id)
    end)
  end
end
