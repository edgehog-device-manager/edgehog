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

defmodule EdgehogWeb.Controllers.AstarteTriggerController.DeploymentUpdatesTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Containers
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.DeviceMapping
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Volume

  require Ash.Query

  describe "process_event for deployment updates" do
    setup %{tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
      device = device_fixture(realm_id: realm.id, tenant: tenant)

      {:ok, cluster: cluster, realm: realm, device: device}
    end

    test "deployment events get queued", context do
      %{
        conn: conn,
        realm: realm,
        device: device,
        tenant: tenant
      } = context

      deployment = deployment_fixture(tenant: tenant, device_id: device.id)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
          path: "/" <> deployment.id,
          value: %{
            "status" => "Error",
            "message" => "error message"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      # Deployment must be reloaded from the db
      deployment =
        Ash.get!(Deployment, deployment.id, tenant: tenant, load: :events)

      assert [event] = deployment.events
      assert event.type == :error
    end

    test "deployment events get queued (event with add_info field)", context do
      %{
        conn: conn,
        realm: realm,
        device: device,
        tenant: tenant
      } = context

      deployment = deployment_fixture(tenant: tenant, device_id: device.id)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
          path: "/" <> deployment.id,
          value: %{
            "status" => "Error",
            "message" => "error message",
            "addInfo" => ["additional info about the event"]
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      # Deployment must be reloaded from the db
      deployment =
        Ash.get!(Deployment, deployment.id, tenant: tenant, load: :events)

      assert [event] = deployment.events
      assert event.type == :error
      assert event.add_info == ["additional info about the event"]
    end

    test "Starting status does not update a Started deployment", context do
      %{
        conn: conn,
        realm: realm,
        device: device,
        tenant: tenant
      } = context

      deployment = deployment_fixture(tenant: tenant, device_id: device.id, state: :started)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
          path: "/" <> deployment.id,
          value: %{
            "status" => "Starting",
            "message" => nil
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      # Deployment must be reloaded from the db
      deployment = Ash.get!(Deployment, deployment.id, tenant: tenant)

      assert deployment.state == :started
    end

    test "AvailableImages triggers update deployment status", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      release =
        [containers: 1, tenant: tenant]
        |> release_fixture()
        |> Ash.load!(containers: [:image])

      [container] = release.containers

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id, state: :stopped]
        |> deployment_fixture()
        |> Ash.load!(:container_deployments)

      [container_deployment] = deployment.container_deployments
      set_ready(container_deployment)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableImages",
          path: "/" <> container.image.id <> "/pulled",
          value: true
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      deployment = Ash.get!(Deployment, deployment.id, tenant: tenant, load: :is_ready)
      assert deployment.is_ready
    end

    test "AvailableVolumes triggers update deployment status", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      release =
        [containers: 1, container_params: [volumes: 1], tenant: tenant]
        |> release_fixture()
        |> Ash.load!(containers: :volumes)

      [container] = release.containers
      [volume] = container.volumes

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id, state: :stopped]
        |> deployment_fixture()
        |> Ash.load!(container_deployments: [:image_deployment])

      [container_deployment] = deployment.container_deployments
      set_ready(container_deployment)

      image_deployment = container_deployment.image_deployment
      set_ready(image_deployment)

      deployment = Ash.get!(Deployment, deployment.id, tenant: tenant, load: :is_ready)
      refute deployment.is_ready

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableVolumes",
          path: "/" <> volume.id <> "/created",
          value: true
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      deployment = Ash.get!(Deployment, deployment.id, tenant: tenant, load: :is_ready)
      assert deployment.is_ready
    end

    test "AvailableContainers triggers update deployment status", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      release =
        [containers: 1, tenant: tenant]
        |> release_fixture()
        |> Ash.load!(:containers)

      [container] = release.containers

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id, state: :sent]
        |> deployment_fixture()
        |> set_ready()
        |> Ash.load!(container_deployments: [:image_deployment])

      [container_deployment] = deployment.container_deployments
      set_ready(container_deployment.image_deployment)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableContainers",
          path: "/" <> container.id <> "/status",
          value: "Created"
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      deployment = Ash.get!(Deployment, deployment.id, tenant: tenant, load: :is_ready)
      assert deployment.is_ready
    end

    test "AvailableDeployments triggers update deployment status", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      release =
        release_fixture(containers: 1, tenant: tenant)

      deployment =
        deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          release_id: release.id,
          state: :sent
        )

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableDeployments",
          path: "/" <> deployment.id <> "/status",
          value: "Stopped"
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      deployment = Ash.get!(Deployment, deployment.id, tenant: tenant)
      assert deployment.state == :stopped
    end

    test "unset AvailableDeployments deletes an existing deployment", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      deployment = deployment_fixture(tenant: tenant, device_id: device.id)

      assert {:ok, deployment} = Ash.get(Deployment, deployment.id, tenant: tenant)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableDeployments",
          path: "/" <> deployment.id <> "/status",
          value: nil
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      refute {:ok, deployment} == Ash.get(Deployment, deployment.id, tenant: tenant)
    end

    test "unset AvailableDeployments deletes an existing deployment and underlying resources if dangling",
         context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      deployment =
        deployment_fixture(tenant: tenant, device_id: device.id, release_opts: [containers: 1])

      {:ok, deployment} =
        Ash.get(Deployment, deployment.id,
          tenant: tenant,
          load: [container_deployments: [:image_deployment]]
        )

      [container_deployment] = deployment.container_deployments
      image_deployment = container_deployment.image_deployment

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableDeployments",
          path: "/" <> deployment.id <> "/status",
          value: nil
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      refute {:ok, deployment} == Ash.get(Deployment, deployment.id, tenant: tenant)
      assert {:error, _} = Ash.get(Container.Deployment, container_deployment.id, tenant: tenant)
      assert {:error, _} = Ash.get(Image.Deployment, image_deployment.id, tenant: tenant)
    end

    test "AvailableDeployments Started status updates deployment state", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      release = release_fixture(containers: 1, tenant: tenant)

      deployment =
        deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          release_id: release.id,
          state: :stopped
        )

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableDeployments",
          path: "/" <> deployment.id <> "/status",
          value: "Started"
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      deployment = Ash.get!(Deployment, deployment.id, tenant: tenant)
      assert deployment.state == :started
    end

    test "AvailableImages with false marks image as unpulled", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      release =
        [containers: 1, tenant: tenant]
        |> release_fixture()
        |> Ash.load!(containers: [:image])

      [container] = release.containers

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id, state: :stopped]
        |> deployment_fixture()
        |> Ash.load!(container_deployments: [:image_deployment])

      [container_deployment] = deployment.container_deployments
      image_deployment = set_ready(container_deployment.image_deployment)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableImages",
          path: "/" <> container.image.id <> "/pulled",
          value: false
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      updated_image_deployment = Ash.get!(Image.Deployment, image_deployment.id, tenant: tenant)
      assert updated_image_deployment.state == :unpulled
    end

    test "AvailableImages with nil destroys image deployment when not referenced", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      # Create a standalone image deployment not associated with a container deployment
      image = image_fixture(tenant: tenant)

      image_deployment =
        image_deployment_fixture(tenant: tenant, device_id: device.id, image_id: image.id)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableImages",
          path: "/" <> image.id <> "/pulled",
          value: nil
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      assert {:error, _} = Ash.get(Image.Deployment, image_deployment.id, tenant: tenant)
    end

    test "AvailableNetworks with true marks network as available", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      network = network_fixture(tenant: tenant)

      network_deployment =
        network_deployment_fixture(tenant: tenant, device_id: device.id, network_id: network.id)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableNetworks",
          path: "/" <> network.id <> "/created",
          value: true
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      updated = Ash.get!(Network.Deployment, network_deployment.id, tenant: tenant)
      assert updated.state == :available
    end

    test "AvailableNetworks with false marks network as unavailable", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      network = network_fixture(tenant: tenant)

      network_deployment =
        network_deployment_fixture(tenant: tenant, device_id: device.id, network_id: network.id)

      set_ready(network_deployment)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableNetworks",
          path: "/" <> network.id <> "/created",
          value: false
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      updated = Ash.get!(Network.Deployment, network_deployment.id, tenant: tenant)
      assert updated.state == :unavailable
    end

    test "AvailableNetworks with nil destroys network deployment", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      network = network_fixture(tenant: tenant)

      network_deployment =
        network_deployment_fixture(tenant: tenant, device_id: device.id, network_id: network.id)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableNetworks",
          path: "/" <> network.id <> "/created",
          value: nil
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      assert {:error, _} = Ash.get(Network.Deployment, network_deployment.id, tenant: tenant)
    end

    test "AvailableVolumes with false marks volume as unavailable", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      volume = volume_fixture(tenant: tenant)

      volume_deployment =
        volume_deployment_fixture(tenant: tenant, device_id: device.id, volume_id: volume.id)

      set_ready(volume_deployment)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableVolumes",
          path: "/" <> volume.id <> "/created",
          value: false
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      updated = Ash.get!(Volume.Deployment, volume_deployment.id, tenant: tenant)
      assert updated.state == :unavailable
    end

    test "AvailableVolumes with nil destroys volume deployment", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      volume = volume_fixture(tenant: tenant)

      volume_deployment =
        volume_deployment_fixture(tenant: tenant, device_id: device.id, volume_id: volume.id)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableVolumes",
          path: "/" <> volume.id <> "/created",
          value: nil
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      assert {:error, _} = Ash.get(Volume.Deployment, volume_deployment.id, tenant: tenant)
    end

    test "AvailableDeviceMappings with true marks device mapping as present", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      device_mapping = device_mapping_fixture(tenant: tenant)

      device_mapping_deployment =
        device_mapping_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          device_mapping_id: device_mapping.id
        )

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableDeviceMappings",
          path: "/" <> device_mapping.id <> "/present",
          value: true
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      updated = Ash.get!(DeviceMapping.Deployment, device_mapping_deployment.id, tenant: tenant)
      assert updated.state == :present
    end

    test "AvailableDeviceMappings with false marks device mapping as not present", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      device_mapping = device_mapping_fixture(tenant: tenant)

      device_mapping_deployment =
        device_mapping_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          device_mapping_id: device_mapping.id
        )

      set_ready(device_mapping_deployment)

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableDeviceMappings",
          path: "/" <> device_mapping.id <> "/present",
          value: false
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      updated = Ash.get!(DeviceMapping.Deployment, device_mapping_deployment.id, tenant: tenant)
      assert updated.state == :not_present
    end

    test "AvailableDeviceMappings with nil destroys device mapping deployment", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      device_mapping = device_mapping_fixture(tenant: tenant)

      device_mapping_deployment =
        device_mapping_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          device_mapping_id: device_mapping.id
        )

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableDeviceMappings",
          path: "/" <> device_mapping.id <> "/present",
          value: nil
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      assert {:error, _} =
               Ash.get(DeviceMapping.Deployment, device_mapping_deployment.id, tenant: tenant)
    end

    test "AvailableContainers with Received status marks container as received", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      release =
        [containers: 1, tenant: tenant]
        |> release_fixture()
        |> Ash.load!(:containers)

      [container] = release.containers

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id, state: :sent]
        |> deployment_fixture()
        |> Ash.load!(container_deployments: [:image_deployment])

      [container_deployment] = deployment.container_deployments

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableContainers",
          path: "/" <> container.id <> "/status",
          value: "Received"
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      updated = Ash.get!(Container.Deployment, container_deployment.id, tenant: tenant)
      assert updated.state == :received
    end

    test "AvailableContainers with Running status marks container as running", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      release =
        [containers: 1, tenant: tenant]
        |> release_fixture()
        |> Ash.load!(:containers)

      [container] = release.containers

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id, state: :sent]
        |> deployment_fixture()
        |> Ash.load!(container_deployments: [:image_deployment])

      [container_deployment] = deployment.container_deployments

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableContainers",
          path: "/" <> container.id <> "/status",
          value: "Running"
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      updated = Ash.get!(Container.Deployment, container_deployment.id, tenant: tenant)
      assert updated.state == :running
    end

    test "AvailableContainers with Stopped status marks container as stopped", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      release =
        [containers: 1, tenant: tenant]
        |> release_fixture()
        |> Ash.load!(:containers)

      [container] = release.containers

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id, state: :sent]
        |> deployment_fixture()
        |> Ash.load!(container_deployments: [:image_deployment])

      [container_deployment] = deployment.container_deployments

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableContainers",
          path: "/" <> container.id <> "/status",
          value: "Stopped"
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      updated = Ash.get!(Container.Deployment, container_deployment.id, tenant: tenant)
      assert updated.state == :stopped
    end

    test "AvailableContainers with nil destroys container deployment", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      release =
        [containers: 1, tenant: tenant]
        |> release_fixture()
        |> Ash.load!(:containers)

      [container] = release.containers

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id, state: :sent]
        |> deployment_fixture()
        |> Ash.load!(container_deployments: [:image_deployment])

      [container_deployment] = deployment.container_deployments

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableContainers",
          path: "/" <> container.id <> "/status",
          value: nil
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      assert {:error, _} = Ash.get(Container.Deployment, container_deployment.id, tenant: tenant)
    end
  end

  defp set_ready(%Image.Deployment{} = deployment),
    do: Containers.mark_image_deployment_as_pulled!(deployment)

  defp set_ready(%Network.Deployment{} = deployment),
    do: Containers.mark_network_deployment_as_available!(deployment)

  defp set_ready(%Volume.Deployment{} = deployment),
    do: Containers.mark_volume_deployment_as_available!(deployment)

  defp set_ready(%DeviceMapping.Deployment{} = deployment),
    do: Containers.mark_device_mapping_deployment_as_present!(deployment)

  defp set_ready(%Container.Deployment{} = deployment),
    do: Containers.mark_container_deployment_as_created!(deployment)

  defp set_ready(%Deployment{} = deployment),
    do: Containers.mark_deployment_as_stopped!(deployment)
end
