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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.ContainerResourceEventSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures

  alias Ash.Astarte.Triggers.Handler
  alias Edgehog.Containers.EnvFile

  setup %{tenant: tenant} do
    cluster = cluster_fixture()
    realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
    device = device_fixture(realm_id: realm.id, tenant: tenant)

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
        device_id: device.id,
        file_mount_id: file_mount.id,
        file_download_request_id: file_download_request.id
      )

    %{
      realm: realm,
      device: device,
      deployment: deployment,
      container_deployment: container_deployment,
      image_deployment: container_deployment.image_deployment,
      volume_deployment: volume_deployment,
      network_deployment: network_deployment,
      env_file: env_file,
      file_bind: file_bind
    }
  end

  describe "releaseDeploymentEvents subscription" do
    test "receives DeploymentEvent for the release deployment", %{
      socket: socket,
      tenant: tenant,
      realm: realm,
      device: device,
      deployment: deployment
    } do
      relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      subscribe(socket, release_deployment_events_query(), %{"id" => relay_id})

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.DeploymentEvent",
        "/" <> deployment.id,
        %{"status" => "Starting", "message" => "Deployment starting", "addInfo" => ["v=1"]}
      )

      assert_push "subscription:data", push

      assert %{
               result: %{
                 data: %{
                   "releaseDeploymentEvents" => %{
                     "__typename" => "DeploymentEvent",
                     "resourceId" => ^relay_id,
                     "status" => "STARTING",
                     "message" => "Deployment starting",
                     "addInfo" => ["v=1"],
                     "timestamp" => "2026-03-19T10:00:00Z"
                   }
                 }
               }
             } = push
    end

    test "accepts a raw UUID for id", %{
      socket: socket,
      tenant: tenant,
      realm: realm,
      device: device,
      deployment: deployment
    } do
      relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      subscribe(socket, release_deployment_events_query(), %{"id" => deployment.id})

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.DeploymentEvent",
        "/" <> deployment.id,
        %{"status" => "Started", "message" => "Started"}
      )

      assert_push "subscription:data", push

      assert %{
               result: %{
                 data: %{
                   "releaseDeploymentEvents" => %{
                     "__typename" => "DeploymentEvent",
                     "resourceId" => ^relay_id,
                     "status" => "STARTED"
                   }
                 }
               }
             } = push
    end

    test " does not receive events for a different deployment", %{
      socket: socket,
      tenant: tenant,
      realm: realm,
      device: device,
      deployment: deployment
    } do
      subscribe(socket, release_deployment_events_query(), %{"id" => Ecto.UUID.generate()})

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.DeploymentEvent",
        "/" <> deployment.id,
        %{"status" => "Starting", "message" => "Deployment starting"}
      )

      refute_push "subscription:data", _push
    end

    test "rejects a Relay ID of a mismatched resource type", %{
      socket: socket,
      container_deployment: container_deployment
    } do
      mismatched_id = AshGraphql.Resource.encode_relay_id(container_deployment)

      ref =
        push_doc(socket, release_deployment_events_query(), variables: %{"id" => mismatched_id})

      assert_reply ref, :error, %{errors: [%{message: "Invalid resource ID"}]}
    end
  end

  describe "hierarchical fan-out across leaf, container, and release deployment subscriptions" do
    test "ContainerEvent fans out to containerDeploymentEvents and releaseDeploymentEvents", %{
      socket: socket,
      tenant: tenant,
      realm: realm,
      device: device,
      deployment: deployment,
      container_deployment: container_deployment
    } do
      deployment_relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      container_relay_id = AshGraphql.Resource.encode_relay_id(container_deployment)

      subscribe(socket, release_deployment_events_query(), %{"id" => deployment_relay_id})
      subscribe(socket, container_deployment_events_query(), %{"id" => container_relay_id})

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.ContainerEvent",
        "/" <> container_deployment.container_id,
        %{"status" => "ExecCreate", "message" => "Exec created", "addInfo" => ["cmd=sh"]}
      )

      expected = %{
        "__typename" => "ContainerDeploymentEvent",
        "resourceId" => container_relay_id,
        "status" => "EXEC_CREATE",
        "message" => "Exec created",
        "addInfo" => ["cmd=sh"],
        "timestamp" => "2026-03-19T10:00:00Z"
      }

      assert_both_pushes(expected, "containerDeploymentEvents", "releaseDeploymentEvents")
    end

    test "ImageEvent fans out to imageDeploymentEvents, containerDeploymentEvents, and releaseDeploymentEvents",
         %{
           socket: socket,
           tenant: tenant,
           realm: realm,
           device: device,
           deployment: deployment,
           container_deployment: container_deployment,
           image_deployment: image_deployment
         } do
      deployment_relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      container_relay_id = AshGraphql.Resource.encode_relay_id(container_deployment)
      image_relay_id = AshGraphql.Resource.encode_relay_id(image_deployment)

      subscribe(socket, release_deployment_events_query(), %{"id" => deployment_relay_id})
      subscribe(socket, container_deployment_events_query(), %{"id" => container_relay_id})

      subscribe(
        socket,
        leaf_subscription_query("imageDeploymentEvents"),
        %{"id" => image_relay_id}
      )

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.ImageEvent",
        "/" <> image_deployment.image_id,
        %{"status" => "Pull", "message" => "Image pulled", "addInfo" => ["tag=latest"]}
      )

      expected = %{
        "__typename" => "ImageDeploymentEvent",
        "resourceId" => image_relay_id,
        "status" => "PULL",
        "message" => "Image pulled",
        "addInfo" => ["tag=latest"],
        "timestamp" => "2026-03-19T10:00:00Z"
      }

      assert_three_pushes(expected, "imageDeploymentEvents")
    end

    test "VolumeEvent fans out to volumeDeploymentEvents, containerDeploymentEvents, and releaseDeploymentEvents",
         %{
           socket: socket,
           tenant: tenant,
           realm: realm,
           device: device,
           deployment: deployment,
           container_deployment: container_deployment,
           volume_deployment: volume_deployment
         } do
      deployment_relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      container_relay_id = AshGraphql.Resource.encode_relay_id(container_deployment)
      volume_relay_id = AshGraphql.Resource.encode_relay_id(volume_deployment)

      subscribe(socket, release_deployment_events_query(), %{"id" => deployment_relay_id})
      subscribe(socket, container_deployment_events_query(), %{"id" => container_relay_id})

      subscribe(
        socket,
        leaf_subscription_query("volumeDeploymentEvents"),
        %{"id" => volume_relay_id}
      )

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.VolumeEvent",
        "/" <> volume_deployment.volume_id,
        %{"status" => "Mount", "message" => "Volume mounted", "addInfo" => ["/data"]}
      )

      expected = %{
        "__typename" => "VolumeDeploymentEvent",
        "resourceId" => volume_relay_id,
        "status" => "MOUNT",
        "message" => "Volume mounted",
        "addInfo" => ["/data"],
        "timestamp" => "2026-03-19T10:00:00Z"
      }

      assert_three_pushes(expected, "volumeDeploymentEvents")
    end

    test "NetworkEvent fans out to networkDeploymentEvents, containerDeploymentEvents, and releaseDeploymentEvents",
         %{
           socket: socket,
           tenant: tenant,
           realm: realm,
           device: device,
           deployment: deployment,
           container_deployment: container_deployment,
           network_deployment: network_deployment
         } do
      deployment_relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      container_relay_id = AshGraphql.Resource.encode_relay_id(container_deployment)
      network_relay_id = AshGraphql.Resource.encode_relay_id(network_deployment)

      subscribe(socket, release_deployment_events_query(), %{"id" => deployment_relay_id})
      subscribe(socket, container_deployment_events_query(), %{"id" => container_relay_id})

      subscribe(
        socket,
        leaf_subscription_query("networkDeploymentEvents"),
        %{"id" => network_relay_id}
      )

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.NetworkEvent",
        "/" <> network_deployment.network_id,
        %{"status" => "Connect", "message" => "Network connected", "addInfo" => ["bridge"]}
      )

      expected = %{
        "__typename" => "NetworkDeploymentEvent",
        "resourceId" => network_relay_id,
        "status" => "CONNECT",
        "message" => "Network connected",
        "addInfo" => ["bridge"],
        "timestamp" => "2026-03-19T10:00:00Z"
      }

      assert_three_pushes(expected, "networkDeploymentEvents")
    end

    test "EnvFileEvent fans out to envFileDeploymentEvents, containerDeploymentEvents, and releaseDeploymentEvents",
         %{
           socket: socket,
           tenant: tenant,
           realm: realm,
           device: device,
           deployment: deployment,
           container_deployment: container_deployment,
           env_file: env_file
         } do
      deployment_relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      container_relay_id = AshGraphql.Resource.encode_relay_id(container_deployment)
      env_file_relay_id = AshGraphql.Resource.encode_relay_id(env_file)

      subscribe(socket, release_deployment_events_query(), %{"id" => deployment_relay_id})
      subscribe(socket, container_deployment_events_query(), %{"id" => container_relay_id})

      subscribe(
        socket,
        leaf_subscription_query("envFileDeploymentEvents"),
        %{"id" => env_file_relay_id}
      )

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.EnvFileEvent",
        "/" <> env_file.id,
        %{"status" => "Error", "message" => "Env file failed", "addInfo" => [".env"]}
      )

      expected = %{
        "__typename" => "EnvFileEvent",
        "resourceId" => env_file_relay_id,
        "status" => "ERROR",
        "message" => "Env file failed",
        "addInfo" => [".env"],
        "timestamp" => "2026-03-19T10:00:00Z"
      }

      assert_three_pushes(expected, "envFileDeploymentEvents")
    end

    test "FileBindEvent fans out to fileBindDeploymentEvents, containerDeploymentEvents, and releaseDeploymentEvents",
         %{
           socket: socket,
           tenant: tenant,
           realm: realm,
           device: device,
           deployment: deployment,
           container_deployment: container_deployment,
           file_bind: file_bind
         } do
      deployment_relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      container_relay_id = AshGraphql.Resource.encode_relay_id(container_deployment)
      file_bind_relay_id = AshGraphql.Resource.encode_relay_id(file_bind)

      subscribe(socket, release_deployment_events_query(), %{"id" => deployment_relay_id})
      subscribe(socket, container_deployment_events_query(), %{"id" => container_relay_id})

      subscribe(
        socket,
        leaf_subscription_query("fileBindDeploymentEvents"),
        %{"id" => file_bind_relay_id}
      )

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.FileBindEvent",
        "/" <> file_bind.id,
        %{"status" => "Error", "message" => "Bind mount failed", "addInfo" => ["EACCES"]}
      )

      expected = %{
        "__typename" => "FileBindEvent",
        "resourceId" => file_bind_relay_id,
        "status" => "ERROR",
        "message" => "Bind mount failed",
        "addInfo" => ["EACCES"],
        "timestamp" => "2026-03-19T10:00:00Z"
      }

      assert_three_pushes(expected, "fileBindDeploymentEvents")
    end
  end

  defp subscribe(socket, query, variables) do
    ref = push_doc(socket, query, variables: variables)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}
    subscription_id
  end

  defp send_trigger(tenant, realm, device, interface, path, value) do
    payload = %{
      "device_id" => device.device_id,
      "timestamp" => "2026-03-19T10:00:00Z",
      "event" => %{
        "type" => "incoming_data",
        "interface" => interface,
        "path" => path,
        "value" => value
      }
    }

    assert :ok = Handler.handle_trigger(tenant, realm.name, payload)
  end

  defp assert_both_pushes(expected, field_a, field_b) do
    assert_push "subscription:data", push1
    assert_push "subscription:data", push2

    data_maps = [push1.result.data, push2.result.data]

    assert Enum.any?(data_maps, &(&1 == %{field_a => expected}))
    assert Enum.any?(data_maps, &(&1 == %{field_b => expected}))
  end

  defp assert_three_pushes(expected, leaf_field) do
    assert_push "subscription:data", push1
    assert_push "subscription:data", push2
    assert_push "subscription:data", push3

    data_maps = [push1.result.data, push2.result.data, push3.result.data]

    assert Enum.any?(data_maps, &(&1 == %{leaf_field => expected}))
    assert Enum.any?(data_maps, &(&1 == %{"containerDeploymentEvents" => expected}))
    assert Enum.any?(data_maps, &(&1 == %{"releaseDeploymentEvents" => expected}))
  end

  defp release_deployment_events_query do
    """
    subscription($id: ID!) {
      releaseDeploymentEvents(id: $id) {
        __typename
        ... on DeploymentEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on ContainerDeploymentEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on ImageDeploymentEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on VolumeDeploymentEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on NetworkDeploymentEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on EnvFileEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on FileBindEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
      }
    }
    """
  end

  defp container_deployment_events_query do
    """
    subscription($id: ID!) {
      containerDeploymentEvents(id: $id) {
        __typename
        ... on ContainerDeploymentEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on ImageDeploymentEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on VolumeDeploymentEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on NetworkDeploymentEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on EnvFileEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
        ... on FileBindEvent {
          resourceId
          status
          message
          addInfo
          timestamp
        }
      }
    }
    """
  end

  defp leaf_subscription_query(field_name) do
    """
    subscription($id: ID!) {
      #{field_name}(id: $id) {
        __typename
        resourceId
        status
        message
        addInfo
        timestamp
      }
    }
    """
  end
end
