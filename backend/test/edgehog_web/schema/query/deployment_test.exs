#
# This file is part of Edgehog.
#
# Copyright 2025-2026 SECO Mind Srl
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
  import Edgehog.FilesFixtures

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
                  isReady
                }
                networkDeployments {
                  edges {
                    node {
                      state
                      isReady
                    }
                  }
                }
                volumeDeployments {
                  edges {
                    node {
                      state
                      isReady
                    }
                  }
                }
                deviceMappingDeployments {
                  edges {
                    node {
                      state
                      isReady
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
    refute container_deployment["imageDeployment"]["isReady"]

    assert [network_deployment] = container_deployment["networkDeployments"]["edges"]
    network_deployment = network_deployment["node"]

    assert network_deployment["state"] == "created"
    refute network_deployment["isReady"]

    assert [volume_deployment] = container_deployment["volumeDeployments"]["edges"]
    volume_deployment = volume_deployment["node"]

    assert volume_deployment["state"] == "created"
    refute volume_deployment["isReady"]

    assert [device_mapping_deployment] =
             container_deployment["deviceMappingDeployments"]["edges"]

    device_mapping_deployment = device_mapping_deployment["node"]

    assert device_mapping_deployment["state"] == "created"
    refute device_mapping_deployment["isReady"]
  end

  test "can access file binds and their relationships through container deployments", %{
    tenant: tenant,
    deployment: deployment
  } do
    [container_deployment] =
      deployment
      |> Ash.load!(:container_deployments, tenant: tenant)
      |> Map.fetch!(:container_deployments)

    file_mount =
      file_mount_fixture(
        tenant: tenant,
        container_id: container_deployment.container_id,
        mountpoint: "/etc/app.conf"
      )

    file_download_request = manual_file_download_request_fixture(tenant: tenant)

    file_bind_fixture(
      tenant: tenant,
      container_deployment_id: container_deployment.id,
      file_mount_id: file_mount.id,
      file_download_request_id: file_download_request.id
    )

    device_file = device_file_fixture(tenant: tenant)

    file_bind_fixture(
      tenant: tenant,
      container_deployment_id: container_deployment.id,
      device_file_id: device_file.id
    )

    document = """
    query($id:ID!) {
      deployment(id:$id) {
        containerDeployments {
          edges {
            node {
              fileBinds {
                fileMount {
                  id
                  mountpoint
                }
                fileDownloadRequest {
                  id
                  status
                }
                deviceFile {
                  id
                  pathOnDevice
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

    assert [%{"node" => %{"fileBinds" => file_binds}}] =
             deployment_result["containerDeployments"]["edges"]

    file_binds_by_id = Map.new(file_binds, &{&1["fileDownloadRequest"]["id"], &1})

    assert file_bind =
             file_binds_by_id[
               AshGraphql.Resource.encode_relay_id(file_download_request)
             ]

    assert %{"fileMount" => %{"id" => file_mount_id, "mountpoint" => "/etc/app.conf"}} =
             file_bind

    assert file_mount_id == AshGraphql.Resource.encode_relay_id(file_mount)

    assert %{
             "fileDownloadRequest" => %{
               "id" => file_download_request_id,
               "status" => status
             }
           } = file_bind

    assert file_download_request_id ==
             AshGraphql.Resource.encode_relay_id(file_download_request)

    refute is_nil(status)

    assert [file_bind] =
             Enum.filter(file_binds, &(&1["deviceFile"]["id"] != nil))

    assert %{
             "deviceFile" => %{
               "id" => device_file_id,
               "pathOnDevice" => path_on_device
             }
           } = file_bind

    assert device_file_id == AshGraphql.Resource.encode_relay_id(device_file)
    assert path_on_device == device_file.path_on_device
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

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  def extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"deployment" => deployment}} = result
    assert deployment

    deployment
  end
end
