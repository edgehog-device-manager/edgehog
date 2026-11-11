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

defmodule EdgehogWeb.Schema.Query.ContainerResourceEventsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures

  alias Edgehog.Astarte.Device.ResourceEvent
  alias Edgehog.Containers.EnvFile

  setup %{tenant: tenant} do
    app = application_fixture(tenant: tenant)
    network = network_fixture(tenant: tenant)
    volume = volume_fixture(tenant: tenant)
    image = image_fixture(tenant: tenant)

    container_params = [
      image: image,
      volumes: [{volume, "/data"}],
      networks: [network]
    ]

    release =
      release_fixture(
        application_id: app.id,
        tenant: tenant,
        containers: 1,
        container_params: container_params
      )

    device = device_fixture(tenant: tenant)

    deployment =
      deployment_fixture(device_id: device.id, release_id: release.id, tenant: tenant)

    [container_deployment] =
      deployment
      |> Ash.load!(
        [
          container_deployments: [
            :image_deployment,
            :volume_deployments,
            :network_deployments
          ]
        ],
        tenant: tenant
      )
      |> Map.fetch!(:container_deployments)

    [volume_deployment] = container_deployment.volume_deployments
    [network_deployment] = container_deployment.network_deployments

    env_file =
      EnvFile
      |> Ash.Changeset.for_create(
        :create,
        %{
          container_deployment_id: container_deployment.id,
          device_id: device.id,
          file_name: ".env"
        },
        tenant: tenant
      )
      |> Ash.create!()

    file_mount =
      file_mount_fixture(
        tenant: tenant,
        container_id: container_deployment.container_id,
        mountpoint: "/etc/app.conf"
      )

    file_download_request = manual_file_download_request_fixture(tenant: tenant)

    file_bind =
      file_bind_fixture(
        tenant: tenant,
        container_deployment_id: container_deployment.id,
        file_mount_id: file_mount.id,
        file_download_request_id: file_download_request.id
      )

    %{
      deployment: deployment,
      device: device,
      container_deployment: container_deployment,
      image_deployment: container_deployment.image_deployment,
      volume_deployment: volume_deployment,
      network_deployment: network_deployment,
      container_id: container_deployment.container_id,
      image_id: container_deployment.image_deployment.image_id,
      volume_id: volume_deployment.volume_id,
      network_id: network_deployment.network_id,
      env_file: env_file,
      file_bind: file_bind
    }
  end

  test "returns events for all container resource deployments", %{
    tenant: tenant,
    deployment: deployment,
    device: device,
    container_deployment: container_deployment,
    image_deployment: image_deployment,
    volume_deployment: volume_deployment,
    network_deployment: network_deployment,
    container_id: container_id,
    image_id: image_id,
    volume_id: volume_id,
    network_id: network_id,
    env_file: env_file,
    file_bind: file_bind
  } do
    device_id = device.device_id
    deployment_id = deployment.id
    env_file_id = env_file.id
    file_bind_id = file_bind.id

    expect(ResourceEvent, :get, 7, fn _client, ^device_id, interface, resource_id, [] ->
      case {interface, resource_id} do
        {"io.edgehog.devicemanager.apps.DeploymentEvent", ^deployment_id} ->
          {:ok,
           [
             %ResourceEvent{
               status: "Starting",
               message: "Deployment starting",
               add_info: ["release=1.0.0"],
               timestamp: ~U[2026-03-19 09:54:00Z]
             },
             %ResourceEvent{
               status: "Started",
               message: "Deployment started",
               add_info: [],
               timestamp: ~U[2026-03-19 10:03:00Z]
             }
           ]}

        {"io.edgehog.devicemanager.apps.ContainerEvent", ^container_id} ->
          {:ok,
           [
             %ResourceEvent{
               status: "Create",
               message: "Container created",
               add_info: ["id=123"],
               timestamp: ~U[2026-03-19 10:00:00Z]
             },
             %ResourceEvent{
               status: "ExecCreate",
               message: "Exec created",
               add_info: [],
               timestamp: ~U[2026-03-19 10:01:00Z]
             },
             %ResourceEvent{
               status: "HealthStatus",
               message: "Healthy",
               add_info: nil,
               timestamp: ~U[2026-03-19 10:02:00Z]
             }
           ]}

        {"io.edgehog.devicemanager.apps.ImageEvent", ^image_id} ->
          {:ok,
           [
             %ResourceEvent{
               status: "Pull",
               message: "Image pulled",
               add_info: ["tag=latest"],
               timestamp: ~U[2026-03-19 09:59:00Z]
             }
           ]}

        {"io.edgehog.devicemanager.apps.VolumeEvent", ^volume_id} ->
          {:ok,
           [
             %ResourceEvent{
               status: "Mount",
               message: "Volume mounted",
               add_info: ["/data"],
               timestamp: ~U[2026-03-19 09:58:00Z]
             }
           ]}

        {"io.edgehog.devicemanager.apps.NetworkEvent", ^network_id} ->
          {:ok,
           [
             %ResourceEvent{
               status: "Connect",
               message: "Network connected",
               add_info: ["driver=bridge"],
               timestamp: ~U[2026-03-19 09:57:00Z]
             }
           ]}

        {"io.edgehog.devicemanager.apps.EnvFileEvent", ^env_file_id} ->
          {:ok,
           [
             %ResourceEvent{
               status: "Error",
               message: "Env file created",
               add_info: [".env"],
               timestamp: ~U[2026-03-19 09:56:00Z]
             }
           ]}

        {"io.edgehog.devicemanager.apps.FileBindEvent", ^file_bind_id} ->
          {:ok,
           [
             %ResourceEvent{
               status: "Error",
               message: "Bind mount failed",
               add_info: ["permission denied"],
               timestamp: ~U[2026-03-19 09:55:00Z]
             }
           ]}
      end
    end)

    document = """
    query($id: ID!) {
      deployment(id: $id) {
        events {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        containerDeployments {
          edges {
            node {
              events {
                resourceId
                status
                message
                addInfo
                timestamp
              }
              imageDeployment {
                events {
                  resourceId
                  status
                  message
                  addInfo
                  timestamp
                }
              }
              volumeDeployments {
                edges {
                  node {
                    events {
                      resourceId
                      status
                      message
                      addInfo
                      timestamp
                    }
                  }
                }
              }
              networkDeployments {
                edges {
                  node {
                    events {
                      resourceId
                      status
                      message
                      addInfo
                      timestamp
                    }
                  }
                }
              }
              envFiles {
                events {
                  resourceId
                  status
                  message
                  addInfo
                  timestamp
                }
              }
              fileBinds {
                events {
                  resourceId
                  status
                  message
                  addInfo
                  timestamp
                }
              }
            }
          }
        }
      }
    }
    """

    id = AshGraphql.Resource.encode_relay_id(deployment)
    container_deployment_relay_id = AshGraphql.Resource.encode_relay_id(container_deployment)
    image_deployment_relay_id = AshGraphql.Resource.encode_relay_id(image_deployment)
    volume_deployment_relay_id = AshGraphql.Resource.encode_relay_id(volume_deployment)
    network_deployment_relay_id = AshGraphql.Resource.encode_relay_id(network_deployment)
    env_file_relay_id = AshGraphql.Resource.encode_relay_id(env_file)
    file_bind_relay_id = AshGraphql.Resource.encode_relay_id(file_bind)

    result =
      [tenant: tenant, id: id, document: document]
      |> get_deployment()
      |> extract_result!()

    assert [
             %{
               "resourceId" => ^id,
               "status" => "STARTING",
               "message" => "Deployment starting",
               "addInfo" => ["release=1.0.0"],
               "timestamp" => "2026-03-19T09:54:00Z"
             },
             %{
               "resourceId" => ^id,
               "status" => "STARTED",
               "message" => "Deployment started",
               "addInfo" => [],
               "timestamp" => "2026-03-19T10:03:00Z"
             }
           ] = result["events"]

    assert [%{"node" => container_node}] = result["containerDeployments"]["edges"]

    assert [
             %{
               "resourceId" => ^container_deployment_relay_id,
               "status" => "CREATE",
               "message" => "Container created",
               "addInfo" => ["id=123"],
               "timestamp" => "2026-03-19T10:00:00Z"
             },
             %{
               "resourceId" => ^container_deployment_relay_id,
               "status" => "EXEC_CREATE",
               "message" => "Exec created",
               "addInfo" => [],
               "timestamp" => "2026-03-19T10:01:00Z"
             },
             %{
               "resourceId" => ^container_deployment_relay_id,
               "status" => "HEALTH_STATUS",
               "message" => "Healthy",
               "addInfo" => [],
               "timestamp" => "2026-03-19T10:02:00Z"
             }
           ] = container_node["events"]

    assert [
             %{
               "resourceId" => ^image_deployment_relay_id,
               "status" => "PULL",
               "message" => "Image pulled",
               "addInfo" => ["tag=latest"],
               "timestamp" => "2026-03-19T09:59:00Z"
             }
           ] = container_node["imageDeployment"]["events"]

    assert [
             %{
               "node" => %{
                 "events" => [
                   %{
                     "resourceId" => ^volume_deployment_relay_id,
                     "status" => "MOUNT",
                     "message" => "Volume mounted",
                     "addInfo" => ["/data"],
                     "timestamp" => "2026-03-19T09:58:00Z"
                   }
                 ]
               }
             }
           ] = container_node["volumeDeployments"]["edges"]

    assert [
             %{
               "node" => %{
                 "events" => [
                   %{
                     "resourceId" => ^network_deployment_relay_id,
                     "status" => "CONNECT",
                     "message" => "Network connected",
                     "addInfo" => ["driver=bridge"],
                     "timestamp" => "2026-03-19T09:57:00Z"
                   }
                 ]
               }
             }
           ] = container_node["networkDeployments"]["edges"]

    assert [
             %{
               "events" => [
                 %{
                   "resourceId" => ^env_file_relay_id,
                   "status" => "ERROR",
                   "message" => "Env file created",
                   "addInfo" => [".env"],
                   "timestamp" => "2026-03-19T09:56:00Z"
                 }
               ]
             }
           ] = container_node["envFiles"]

    assert [
             %{
               "events" => [
                 %{
                   "resourceId" => ^file_bind_relay_id,
                   "status" => "ERROR",
                   "message" => "Bind mount failed",
                   "addInfo" => ["permission denied"],
                   "timestamp" => "2026-03-19T09:55:00Z"
                 }
               ]
             }
           ] = container_node["fileBinds"]
  end

  test "returns empty list when Astarte returns no events", %{
    tenant: tenant,
    deployment: deployment,
    device: device,
    container_id: container_id
  } do
    device_id = device.device_id
    deployment_id = deployment.id

    expect(ResourceEvent, :get, 2, fn _client, ^device_id, interface, resource_id, [] ->
      case {interface, resource_id} do
        {"io.edgehog.devicemanager.apps.DeploymentEvent", ^deployment_id} ->
          {:ok, []}

        {"io.edgehog.devicemanager.apps.ContainerEvent", ^container_id} ->
          {:ok, []}
      end
    end)

    document = """
    query($id: ID!) {
      deployment(id: $id) {
        events {
          status
          message
          addInfo
          timestamp
        }
        containerDeployments {
          edges {
            node {
              events {
                status
                message
                timestamp
              }
            }
          }
        }
      }
    }
    """

    id = AshGraphql.Resource.encode_relay_id(deployment)

    result =
      [tenant: tenant, id: id, document: document]
      |> get_deployment()
      |> extract_result!()

    assert result["events"] == []

    assert [%{"node" => %{"events" => []}}] =
             result["containerDeployments"]["edges"]
  end

  test "returns nil when Astarte returns an error", %{
    tenant: tenant,
    deployment: deployment,
    device: device,
    container_id: container_id
  } do
    device_id = device.device_id
    deployment_id = deployment.id

    expect(ResourceEvent, :get, 2, fn _client, ^device_id, interface, resource_id, [] ->
      case {interface, resource_id} do
        {"io.edgehog.devicemanager.apps.DeploymentEvent", ^deployment_id} ->
          {:error, :astarte_error}

        {"io.edgehog.devicemanager.apps.ContainerEvent", ^container_id} ->
          {:error, :astarte_error}
      end
    end)

    document = """
    query($id: ID!) {
      deployment(id: $id) {
        events {
          status
          message
          addInfo
          timestamp
        }
        containerDeployments {
          edges {
            node {
              events {
                status
                message
                timestamp
              }
            }
          }
        }
      }
    }
    """

    id = AshGraphql.Resource.encode_relay_id(deployment)

    result =
      [tenant: tenant, id: id, document: document]
      |> get_deployment()
      |> extract_result!()

    assert result["events"] == nil

    assert [%{"node" => %{"events" => nil}}] =
             result["containerDeployments"]["edges"]
  end

  defp get_deployment(opts) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.fetch!(opts, :document)
    id = Keyword.fetch!(opts, :id)
    extra_variables = Keyword.get(opts, :variables, %{})
    variables = Map.put(extra_variables, "id", id)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"deployment" => deployment}} = result
    assert deployment

    deployment
  end
end
