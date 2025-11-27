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

defmodule EdgehogWeb.Schema.Query.DeploymentTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  setup %{tenant: tenant} do
    app = application_fixture(tenant: tenant)
    network = network_fixture(tenant: tenant)
    volume_target = "/var/local/fixture#{System.unique_integer([:positive])}"
    device_mapping = device_mapping_fixture(tenant: tenant)

    container_params = [
      volumes: 1,
      volume_target: volume_target,
      networks: [network.id],
      device_mappings: [device_mapping.id]
    ]

    release =
      [application_id: app.id, tenant: tenant, containers: 1, container_params: container_params]
      |> release_fixture()
      |> Ash.load!(:containers)

    [container] = release.containers

    device = device_fixture(tenant: tenant)

    deployment =
      deployment_fixture(device_id: device.id, release_id: release.id, tenant: tenant)

    %{deployment: deployment, release: release, device: device, container: container}
  end

  test "can access release and device trough relationships", %{
    tenant: tenant,
    deployment: deployment,
    release: release,
    device: device
  } do
    id = AshGraphql.Resource.encode_relay_id(deployment)

    deployment_result =
      [tenant: tenant, id: id]
      |> get_deployment()
      |> extract_result!()

    expected_release_id = AshGraphql.Resource.encode_relay_id(release)
    expected_device_id = AshGraphql.Resource.encode_relay_id(device)

    assert deployment_result["release"]["id"] == expected_release_id
    assert deployment_result["device"]["id"] == expected_device_id
  end

  test "can access underlying resources states", %{tenant: tenant, deployment: deployment} do
    document = """
      query($id:ID!) {
        deployment(id:$id) {
          state
          containerDeployments {
            edges {
              node {
                state
                imageDeployment {
                  state
                }
                networkDeployments {
                  edges {
                    node {
                      state
                    }
                  }
                }
                volumeDeployments {
                  edges {
                    node {
                      state
                    }
                  }
                }
              }
            }
          }
        }
      }
    """

    id = AshGraphql.Resource.encode_relay_id(deployment)

    deployment_result =
      [tenant: tenant, id: id, document: document]
      |> get_deployment()
      |> extract_result!()

    assert deployment_result["state"] == "PENDING"

    assert [container_deployment] = deployment_result["containerDeployments"]["edges"]
    container_deployment = container_deployment["node"]

    assert container_deployment["imageDeployment"]["state"] == "created"

    assert [network_deployment] = container_deployment["networkDeployments"]["edges"]
    network_deployment = network_deployment["node"]

    assert network_deployment["state"] == "created"

    assert [volume_deployment] = container_deployment["volumeDeployments"]["edges"]
    volume_deployment = volume_deployment["node"]

    assert volume_deployment["state"] == "created"
  end

  defp get_deployment(opts) do
    default_document =
      """
      query ($id: ID!) {
        deployment(id: $id) {
          id
          release {
            id
          }
          device {
            id
          }
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    id = Keyword.fetch!(opts, :id)
    variables = %{"id" => id}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"deployment" => deployment}} = result
    assert deployment

    deployment
  end
end
