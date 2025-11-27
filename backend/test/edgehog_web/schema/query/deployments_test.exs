#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.DeploymentsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Containers.ContainerNetwork
  alias Edgehog.Containers.ReleaseContainers

  setup %{tenant: tenant} do
    app = application_fixture(tenant: tenant)
    release = release_fixture(application_id: app.id, tenant: tenant)

    container = container_fixture(tenant: tenant)
    network = network_fixture(tenant: tenant)

    params = %{container_id: container.id, release_id: release.id}
    Ash.create!(ReleaseContainers, params, tenant: tenant)

    params = %{container_id: container.id, network_id: network.id}
    Ash.create!(ContainerNetwork, params, tenant: tenant)

    device = device_fixture(tenant: tenant)

    deployment =
      deployment_fixture(device_id: device.id, release_id: release.id, tenant: tenant)

    %{
      application: app,
      release: release,
      container: container,
      network: network,
      device: device,
      deployment: deployment
    }
  end

  test "can access release and device trough relationships", context do
    %{tenant: tenant, deployment: deployment, device: device, release: release} = context

    id = AshGraphql.Resource.encode_relay_id(deployment)

    deployment_result =
      [tenant: tenant, id: id]
      |> list_deployments()
      |> extract_result!()

    expected_release_id = AshGraphql.Resource.encode_relay_id(release)
    expected_device_id = AshGraphql.Resource.encode_relay_id(device)

    assert [deployment_result] = deployment_result["deployments"]["edges"]
    assert deployment_result["node"]["release"]["id"] == expected_release_id
    assert deployment_result["node"]["device"]["id"] == expected_device_id
  end

  test "can filter based on device", context do
    %{tenant: tenant, release: release} = context
    device = device_fixture(tenant: tenant)

    deployment_fixture(device_id: device.id, release_id: release.id, tenant: tenant)

    document =
      """
      query($filter: DeploymentFilterInput!) {
        deployments(filter: $filter) {
          edges {
            node {
              release {
                id
              }
            }
          }
        }
      }
      """

    variables = %{"filter" => %{"device" => %{"id" => %{"eq" => device.id}}}}

    deployment_result =
      [tenant: tenant, document: document, variables: variables]
      |> list_deployments()
      |> extract_result!()

    expected_release_id = AshGraphql.Resource.encode_relay_id(release)

    assert [deployment_result] = deployment_result["deployments"]["edges"]
    assert deployment_result["node"]["release"]["id"] == expected_release_id
  end

  test "can filter based on release", context do
    %{tenant: tenant, device: device, application: app} = context

    release = release_fixture(application_id: app.id, tenant: tenant)

    deployment_fixture(device_id: device.id, release_id: release.id, tenant: tenant)

    document =
      """
      query($filter: DeploymentFilterInput!) {
        deployments(filter: $filter) {
          edges {
            node {
              device {
                id
              }
            }
          }
        }
      }
      """

    variables = %{"filter" => %{"release" => %{"id" => %{"eq" => release.id}}}}

    deployment_result =
      [tenant: tenant, document: document, variables: variables]
      |> list_deployments()
      |> extract_result!()

    expected_device_id = AshGraphql.Resource.encode_relay_id(device)

    assert [deployment_result] = deployment_result["deployments"]["edges"]
    assert deployment_result["node"]["device"]["id"] == expected_device_id
  end

  defp list_deployments(opts) do
    default_document =
      """
      query {
        deployments {
          edges {
            node {
              release {
                id
              }
              device {
                id
              }
            }
          }
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    id = Keyword.get(opts, :id)
    variables = Keyword.get(opts, :variables, %{"id" => id})

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: data} = result
    assert data

    data
  end
end
