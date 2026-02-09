#
# This file is part of Edgehog.
#
# Copyright 2021 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Controllers.AstarteTriggerControllerTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.OSManagementFixtures

  alias Edgehog.Astarte.Device.DeviceStatusMock
  alias Edgehog.Containers
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.DeviceMapping
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Reconciler
  alias Edgehog.Containers.ReconcilerMock
  alias Edgehog.Containers.Volume
  alias Edgehog.Devices.Device
  alias Edgehog.OSManagement

  require Ash.Query

  describe "process_event for device events" do
    setup %{conn: conn, tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)

      device =
        device_fixture(
          realm_id: realm.id,
          online: false,
          last_connection: DateTime.add(utc_now_second(), -50, :minute),
          last_disconnection: DateTime.add(utc_now_second(), -10, :minute),
          last_seen_ip: "198.51.100.25",
          tenant: tenant
        )

      conn = put_req_header(conn, "astarte-realm", realm.name)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)
      stub(ReconcilerMock, :register_device, fn _device, _tenant -> :ok end)
      stub(ReconcilerMock, :stop_device, fn _device, _tenant -> :ok end)
      stub(ReconcilerMock, :start_link, fn _opts -> :ok end)

      {:ok, conn: conn, cluster: cluster, realm: realm, device: device, path: path}
    end

    test "creates an unexisting device and populates it from Device Status", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        tenant: tenant
      } = ctx

      device_id = random_device_id()
      timestamp = utc_now_second()
      event = connection_trigger(device_id, timestamp)

      astarte_disconnection_timestamp = DateTime.add(timestamp, -1, :hour)

      expect(DeviceStatusMock, :get, fn _client, ^device_id ->
        device_status =
          device_status_fixture(
            online: true,
            last_connection: timestamp,
            last_disconnection: astarte_disconnection_timestamp
          )

        {:ok, device_status}
      end)

      assert conn |> post(path, event) |> response(200)

      assert {:ok, device} = fetch_device(realm, device_id, tenant)

      assert %Device{
               online: true,
               last_connection: ^timestamp,
               last_disconnection: ^astarte_disconnection_timestamp
             } = device
    end

    test "uses Device Status as the ultimate source of truth when creating a new device", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        tenant: tenant
      } = ctx

      device_id = random_device_id()
      timestamp = utc_now_second()
      event = connection_trigger(device_id, timestamp)

      astarte_disconnection_timestamp = DateTime.add(timestamp, 1, :second)

      # We simulate the fact that the device has already disconnected
      expect(DeviceStatusMock, :get, fn _client, ^device_id ->
        {:ok, device_status_fixture(online: false, last_disconnection: astarte_disconnection_timestamp)}
      end)

      assert conn |> post(path, event) |> response(200)

      assert {:ok, %Device{online: false, last_disconnection: ^astarte_disconnection_timestamp}} =
               fetch_device(realm, device_id, tenant)
    end

    test "ignores errors on Device Status retrieval for unexisting device", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        tenant: tenant
      } = ctx

      device_id = random_device_id()
      timestamp = utc_now_second()
      event = connection_trigger(device_id, timestamp)

      expect(DeviceStatusMock, :get, fn _client, ^device_id ->
        {:error, api_error(status: 500, message: "Internal Server Error")}
      end)

      assert conn |> post(path, event) |> response(200)

      assert {:ok, device} = fetch_device(realm, device_id, tenant)

      assert %Device{
               online: true,
               last_connection: ^timestamp,
               last_disconnection: nil
             } = device
    end

    test "connection events update an existing device, not calling Astarte", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        tenant: tenant
      } = ctx

      %Device{device_id: device_id} =
        device_fixture(
          realm_id: realm.id,
          online: false,
          last_connection: DateTime.add(utc_now_second(), -50, :minute),
          last_disconnection: DateTime.add(utc_now_second(), -10, :minute),
          last_seen_ip: "198.51.100.25",
          tenant: tenant
        )

      timestamp = utc_now_second()
      event = connection_trigger(device_id, timestamp)

      expect(DeviceStatusMock, :get, 0, fn _client, _device_id -> flunk() end)
      assert conn |> post(path, event) |> response(200)

      assert {:ok, device} = fetch_device(realm, device_id, tenant)

      assert %Device{
               online: true,
               last_connection: ^timestamp
             } = device
    end

    test "creates an empty device from a registration event", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        tenant: tenant
      } = ctx

      device_id = random_device_id()
      timestamp = utc_now_second()
      event = registration_trigger(device_id, timestamp)

      assert conn |> post(path, event) |> response(200)

      assert {:ok, device} = fetch_device(realm, device_id, tenant)

      assert %Device{
               device_id: ^device_id,
               name: ^device_id,
               online: false,
               last_connection: nil,
               last_disconnection: nil
             } = device
    end

    test "remove an existing device after device deletion finished on astarte", ctx do
      %{device: device, conn: conn, path: path, realm: realm, tenant: tenant} = ctx

      timestamp = utc_now_second()
      event = deletion_finished_trigger(device.device_id, timestamp)

      assert conn |> post(path, event) |> response(200)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               fetch_device(realm, device.device_id, tenant)
    end

    test "accepts trigger payload without `trigger_name` key (Astarte < 1.2.0)", ctx do
      %{conn: conn, path: path} = ctx

      stub(DeviceStatusMock, :get, fn _client, _device_id -> {:ok, device_status_fixture()} end)

      device_id = random_device_id()
      timestamp = utc_now_second()

      astarte_pre_1_2_0_event =
        device_id
        |> connection_trigger(timestamp)
        |> Map.delete(:trigger_name)

      assert conn |> post(path, astarte_pre_1_2_0_event) |> response(200)
    end

    test "accepts arbitrary additional keys in the trigger payload", ctx do
      %{conn: conn, path: path} = ctx

      stub(DeviceStatusMock, :get, fn _client, _device_id -> {:ok, device_status_fixture()} end)

      device_id = random_device_id()
      timestamp = utc_now_second()

      extra_key_event =
        device_id
        |> connection_trigger(timestamp)
        |> Map.put(:random, "key")

      assert conn |> post(path, extra_key_event) |> response(200)
    end

    test "disconnection events update an existing device, not calling Astarte", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        tenant: tenant
      } = ctx

      %Device{device_id: device_id} =
        device_fixture(
          realm_id: realm.id,
          online: true,
          last_connection: DateTime.add(utc_now_second(), -10, :minute),
          last_disconnection: DateTime.add(utc_now_second(), -50, :minute),
          last_seen_ip: "198.51.100.25",
          tenant: tenant
        )

      timestamp = utc_now_second()
      event = disconnection_trigger(device_id, timestamp)

      expect(DeviceStatusMock, :get, 0, fn _client, _device_id -> flunk() end)
      assert conn |> post(path, event) |> response(200)

      assert {:ok, device} = fetch_device(realm, device_id, tenant)

      assert %Device{
               online: false,
               last_disconnection: ^timestamp
             } = device
    end

    test "disconnection events stop the device container reconciler", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        tenant: tenant
      } = ctx

      stub(
        ReconcilerMock,
        :stop_device,
        &Reconciler.stop_device/2
      )

      device =
        device_fixture(
          realm_id: realm.id,
          online: true,
          last_connection: DateTime.add(utc_now_second(), -10, :minute),
          last_disconnection: DateTime.add(utc_now_second(), -50, :minute),
          last_seen_ip: "198.51.100.25",
          tenant: tenant
        )

      timestamp = utc_now_second()
      event = disconnection_trigger(device.device_id, timestamp)

      Registry.register(Edgehog.Containers.Reconciler.Registry, tenant.tenant_id, self())

      stub(DeviceStatusMock, :get, fn _client, _device_id -> flunk() end)
      assert conn |> post(path, event) |> response(200)

      assert {:ok, device} = fetch_device(realm, device.device_id, tenant)

      assert %Device{
               online: false,
               last_disconnection: ^timestamp
             } = device

      device_id = device.id
      assert_receive {:"$gen_cast", {:stop, %Device{id: ^device_id}}}, 1000
    end

    test "creates an unexisting device when receiving an unhandled event", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        tenant: tenant
      } = ctx

      device_id = random_device_id()
      event = unknown_trigger(device_id)
      connection_timestamp = DateTime.add(utc_now_second(), -10, :minute)
      disconnection_timestamp = DateTime.add(connection_timestamp, -40, :minute)

      expect(DeviceStatusMock, :get, fn _client, ^device_id ->
        device_status =
          device_status_fixture(
            online: true,
            last_connection: connection_timestamp,
            last_disconnection: disconnection_timestamp
          )

        {:ok, device_status}
      end)

      assert conn |> post(path, event) |> response(200)

      assert {:ok, device} = fetch_device(realm, device_id, tenant)

      assert %Device{
               online: true,
               last_connection: ^connection_timestamp,
               last_disconnection: ^disconnection_timestamp
             } = device
    end

    test "updates an existing device when receiving serial number", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        device: %{device_id: device_id},
        tenant: tenant
      } = ctx

      event = serial_number_trigger(device_id, "12345")
      assert conn |> post(path, event) |> response(200)

      assert {:ok, %Device{online: true, serial_number: "12345"}} =
               fetch_device(realm, device_id, tenant)
    end

    test "associates a device with a system model when receiving part number", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        device: %{device_id: device_id},
        tenant: tenant
      } = ctx

      system_model = system_model_fixture(tenant: tenant)
      [%{part_number: part_number}] = system_model.part_numbers

      event = part_number_trigger(device_id, part_number)

      assert conn |> post(path, event) |> response(200)

      assert {:ok, device} = fetch_device(realm, device_id, tenant, [:system_model])
      assert device.online == true
      assert device.part_number == part_number
      assert device.system_model.id == system_model.id
      assert device.system_model.name == system_model.name
      assert device.system_model.handle == system_model.handle
    end

    test "saves a device's part number when SystemModelPartNumber does not exist", ctx do
      %{
        conn: conn,
        path: path,
        realm: realm,
        device: %{device_id: device_id},
        tenant: tenant
      } = ctx

      part_number = "PN12345"
      event = part_number_trigger(device_id, part_number)

      assert conn |> post(path, event) |> response(200)

      assert {:ok, device} =
               fetch_device(realm, device_id, tenant, [:system_model, :system_model_part_number])

      assert device.online == true
      assert device.part_number == part_number
      assert device.system_model_part_number == nil
      assert device.system_model == nil
    end

    test "trigger with missing astarte-realm header returns error", ctx do
      %{
        conn: conn,
        path: path,
        device: %{device_id: device_id}
      } = ctx

      event = connection_trigger(device_id, utc_now_second())

      assert conn
             |> delete_req_header("astarte-realm")
             |> post(path, event)
             |> response(400)
    end

    test "trigger with non-existing realm returns error", ctx do
      %{
        conn: conn,
        path: path,
        device: %{device_id: device_id}
      } = ctx

      event = connection_trigger(device_id, utc_now_second())

      assert conn
             |> put_req_header("astarte-realm", "invalid")
             |> post(path, event)
             |> response(404)
    end

    test "with an unexisting tenant returns 403", ctx do
      %{
        conn: conn
      } = ctx

      path = Routes.astarte_trigger_path(conn, :process_event, "notexists")
      event = connection_trigger(random_device_id(), utc_now_second())

      assert conn |> post(path, event) |> response(403)
    end

    test "trigger with invalid event values returns error", ctx do
      %{
        conn: conn,
        path: path,
        device: %{device_id: device_id}
      } = ctx

      unprocessable_event = %{
        device_id: device_id,
        event: %{type: "unknown"},
        timestamp: DateTime.to_unix(DateTime.utc_now())
      }

      assert conn |> post(path, unprocessable_event) |> response(422)
    end

    test "with different tenant does not find realm and returns error", ctx do
      %{
        conn: conn,
        device: %{device_id: device_id}
      } = ctx

      other_tenant = Edgehog.TenantsFixtures.tenant_fixture(slug: "other")
      path = Routes.astarte_trigger_path(conn, :process_event, other_tenant.slug)
      event = connection_trigger(device_id, utc_now_second())

      assert conn |> post(path, event) |> response(404)
    end
  end

  describe "deployment events" do
    setup %{tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
      device = device_fixture(realm_id: realm.id, tenant: tenant)
      deployment = deployment_fixture(tenant: tenant, device_id: device.id)

      {:ok, cluster: cluster, realm: realm, device: device, deployment: deployment}
    end

    test "do not update the state", context do
      %{
        conn: conn,
        realm: realm,
        device: device,
        tenant: tenant,
        deployment: deployment
      } = context

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
      new_deployment = Ash.get!(Deployment, deployment.id, tenant: tenant)

      assert deployment.state == new_deployment.state
    end

    for event <- [:starting, :stopping, :error] do
      test "A new #{event} gets created on interface publish", context do
        %{
          conn: conn,
          realm: realm,
          device: device,
          tenant: tenant,
          deployment: deployment
        } = context

        event_value = event_value(unquote(event), "test_event_message")
        timestamp = DateTime.to_iso8601(DateTime.utc_now())

        deployment_event = %{
          device_id: device.device_id,
          event: %{
            type: "incoming_data",
            interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
            path: "/" <> deployment.id,
            value: event_value
          },
          timestamp: timestamp
        }

        path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, deployment_event)
        |> response(200)

        assert [event] =
                 deployment
                 |> Ash.load!(:events)
                 |> Map.fetch!(:events)

        assert unquote(event) = event.type
        assert "test_event_message" = event.message
      end
    end
  end

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

  describe "process_event/2 for OTA updates" do
    setup %{tenant: tenant} do
      # Some events might trigger an ephemeral image deletion
      stub(Edgehog.OSManagement.EphemeralImageMock, :delete, fn _tenant_id, _ota_operation_id, _url ->
        :ok
      end)

      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
      device = device_fixture(realm_id: realm.id, tenant: tenant)

      {:ok, cluster: cluster, realm: realm, device: device}
    end

    test "updates the OTA operation when receiving an event on the OTAEvent interface", context do
      %{
        conn: conn,
        realm: realm,
        device: device,
        tenant: tenant
      } = context

      ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      ota_event = %{
        trigger_name: "edgehog-ota-event",
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAEvent",
          path: "/event",
          value: %{
            "requestUUID" => ota_operation.id,
            "status" => "Downloading",
            "statusProgress" => 50,
            "statusCode" => nil,
            "message" => "Waiting for download to finish"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn =
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, ota_event)

      assert response(conn, 200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)

      assert operation.status == :downloading
      assert operation.status_code == nil
      assert operation.status_progress == 50
      assert operation.message == "Waiting for download to finish"
    end

    test "adapts events received on the legacy OTAResponse interface", context do
      %{
        conn: conn,
        realm: realm,
        device: device,
        tenant: tenant
      } = context

      ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      ota_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAResponse",
          path: "/response",
          value: %{
            "uuid" => ota_operation.id,
            "status" => "Error",
            "statusCode" => "OTAErrorNetwork"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn =
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, ota_event)

      assert response(conn, 200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)

      assert operation.status == :failure
      assert operation.status_code == :network_error
    end

    test "supports empty strings for status code in legacy OTAResponse interface", context do
      %{
        conn: conn,
        realm: realm,
        device: device,
        tenant: tenant
      } = context

      ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      ota_event = %{
        trigger_name: "edgehog-ota-event",
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAResponse",
          path: "/response",
          value: %{
            "uuid" => ota_operation.id,
            "status" => "Error",
            "statusCode" => ""
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn =
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, ota_event)

      assert response(conn, 200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)

      assert operation.status_code == nil
    end

    test "translates InProgress status in legacy OTAResponse to Acknowledged", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      ota_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAResponse",
          path: "/response",
          value: %{
            "uuid" => ota_operation.id,
            "status" => "InProgress",
            "statusCode" => nil
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, ota_event)
      |> response(200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)
      assert operation.status == :acknowledged
    end

    test "translates Done status in legacy OTAResponse to Success", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      ota_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAResponse",
          path: "/response",
          value: %{
            "uuid" => ota_operation.id,
            "status" => "Done",
            "statusCode" => nil
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, ota_event)
      |> response(200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)
      assert operation.status == :success
    end

    test "translates OTAAlreadyInProgress status code in legacy OTAResponse", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      ota_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAResponse",
          path: "/response",
          value: %{
            "uuid" => ota_operation.id,
            "status" => "Error",
            "statusCode" => "OTAAlreadyInProgress"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, ota_event)
      |> response(200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)
      assert operation.status_code == :update_already_in_progress
    end

    test "translates OTAErrorDeploy status code in legacy OTAResponse", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      ota_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAResponse",
          path: "/response",
          value: %{
            "uuid" => ota_operation.id,
            "status" => "Error",
            "statusCode" => "OTAErrorDeploy"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, ota_event)
      |> response(200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)
      assert operation.status_code == :io_error
    end

    test "translates OTAErrorBootWrongPartition status code in legacy OTAResponse", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      ota_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAResponse",
          path: "/response",
          value: %{
            "uuid" => ota_operation.id,
            "status" => "Error",
            "statusCode" => "OTAErrorBootWrongPartition"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, ota_event)
      |> response(200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)
      assert operation.status_code == :system_rollback
    end

    test "translates OTAErrorNvs status code in legacy OTAResponse to nil", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      ota_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAResponse",
          path: "/response",
          value: %{
            "uuid" => ota_operation.id,
            "status" => "Error",
            "statusCode" => "OTAErrorNvs"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, ota_event)
      |> response(200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)
      assert operation.status_code == nil
    end

    test "translates OTAFailed status code in legacy OTAResponse to nil", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      ota_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAResponse",
          path: "/response",
          value: %{
            "uuid" => ota_operation.id,
            "status" => "Error",
            "statusCode" => "OTAFailed"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, ota_event)
      |> response(200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)
      assert operation.status_code == nil
    end
  end

  defp fetch_device(realm, device_id, tenant, load \\ []) do
    Ash.get(Device, %{realm_id: realm.id, device_id: device_id}, tenant: tenant, load: load)
  end

  defp utc_now_second do
    DateTime.truncate(DateTime.utc_now(), :second)
  end

  defp registration_trigger(device_id, timestamp) do
    %{
      trigger_name: "edgehog-registration",
      device_id: device_id,
      event: %{
        type: "device_registered"
      },
      timestamp: DateTime.to_iso8601(timestamp)
    }
  end

  defp deletion_finished_trigger(device_id, timestamp) do
    %{
      trigger_name: "edgehog-deletion-finished",
      device_id: device_id,
      event: %{
        type: "device_deletion_finished"
      },
      timestamp: DateTime.to_iso8601(timestamp)
    }
  end

  defp connection_trigger(device_id, timestamp) do
    %{
      trigger_name: "edgehog-connection",
      device_id: device_id,
      event: %{
        type: "device_connected",
        device_ip_address: "1.2.3.4"
      },
      timestamp: DateTime.to_iso8601(timestamp)
    }
  end

  defp disconnection_trigger(device_id, timestamp) do
    %{
      trigger_name: "edgehog-disconnection",
      device_id: device_id,
      event: %{
        type: "device_disconnected"
      },
      timestamp: DateTime.to_iso8601(timestamp)
    }
  end

  @system_info_interface "io.edgehog.devicemanager.SystemInfo"

  defp part_number_trigger(device_id, part_number) do
    %{
      trigger_name: "edgehog-system-info",
      device_id: device_id,
      event: %{
        type: "incoming_data",
        interface: @system_info_interface,
        path: "/partNumber",
        value: part_number
      },
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp serial_number_trigger(device_id, serial_number) do
    %{
      trigger_name: "edgehog-system-info",
      device_id: device_id,
      event: %{
        type: "incoming_data",
        interface: @system_info_interface,
        path: "/serialNumber",
        value: serial_number
      },
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp unknown_trigger(device_id) do
    %{
      trigger_name: "other-trigger",
      device_id: device_id,
      event: %{
        type: "incoming_data",
        interface: "org.example.SomeOtherInterface",
        path: "/foo",
        value: 42
      },
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp api_error(opts) do
    status = Keyword.get(opts, :status, 500)
    message = Keyword.get(opts, :message, "Generic error")

    %Astarte.Client.APIError{
      status: status,
      response: %{"errors" => %{"detail" => message}}
    }
  end

  defp set_ready(%Image.Deployment{} = deployment), do: Containers.mark_image_deployment_as_pulled!(deployment)

  defp set_ready(%Network.Deployment{} = deployment), do: Containers.mark_network_deployment_as_available!(deployment)

  defp set_ready(%Volume.Deployment{} = deployment), do: Containers.mark_volume_deployment_as_available!(deployment)

  defp set_ready(%DeviceMapping.Deployment{} = deployment),
    do: Containers.mark_device_mapping_deployment_as_present!(deployment)

  defp set_ready(%Container.Deployment{} = deployment), do: Containers.mark_container_deployment_as_created!(deployment)

  defp set_ready(%Deployment{} = deployment), do: Containers.mark_deployment_as_stopped!(deployment)

  defp event_value(event, message), do: %{"status" => event |> to_string() |> String.capitalize(), "message" => message}
end
