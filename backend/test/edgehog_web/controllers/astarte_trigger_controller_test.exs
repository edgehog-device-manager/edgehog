#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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
  use Edgehog.EphemeralImageMockCase

  alias Edgehog.Devices.Device
  alias Edgehog.OSManagement

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.OSManagementFixtures

  describe "process_event for device events" do
    setup %{conn: conn, tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)

      device =
        device_fixture(
          realm_id: realm.id,
          online: false,
          last_connection: utc_now_second() |> DateTime.add(-50, :minute),
          last_disconnection: utc_now_second() |> DateTime.add(-10, :minute),
          tenant: tenant
        )

      conn = put_req_header(conn, "astarte-realm", realm.name)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

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

      Edgehog.Astarte.Device.DeviceStatusMock
      |> expect(:get, fn _client, ^device_id ->
        device_status =
          [
            online: true,
            last_connection: timestamp,
            last_disconnection: astarte_disconnection_timestamp
          ]
          |> device_status_fixture()

        {:ok, device_status}
      end)

      assert post(conn, path, event) |> response(200)

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
      Edgehog.Astarte.Device.DeviceStatusMock
      |> expect(:get, fn _client, ^device_id ->
        {:ok,
         device_status_fixture(online: false, last_disconnection: astarte_disconnection_timestamp)}
      end)

      assert post(conn, path, event) |> response(200)

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

      Edgehog.Astarte.Device.DeviceStatusMock
      |> expect(:get, fn _client, ^device_id ->
        {:error, api_error(status: 500, message: "Internal Server Error")}
      end)

      assert post(conn, path, event) |> response(200)

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
          last_connection: utc_now_second() |> DateTime.add(-50, :minute),
          last_disconnection: utc_now_second() |> DateTime.add(-10, :minute),
          tenant: tenant
        )

      timestamp = utc_now_second()
      event = connection_trigger(device_id, timestamp)

      Edgehog.Astarte.Device.DeviceStatusMock
      |> expect(:get, 0, fn _client, _device_id -> flunk() end)

      assert post(conn, path, event) |> response(200)

      assert {:ok, device} = fetch_device(realm, device_id, tenant)

      assert %Device{
               online: true,
               last_connection: ^timestamp
             } = device
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
          last_connection: utc_now_second() |> DateTime.add(-10, :minute),
          last_disconnection: utc_now_second() |> DateTime.add(-50, :minute),
          tenant: tenant
        )

      timestamp = utc_now_second()
      event = disconnection_trigger(device_id, timestamp)

      Edgehog.Astarte.Device.DeviceStatusMock
      |> expect(:get, 0, fn _client, _device_id -> flunk() end)

      assert post(conn, path, event) |> response(200)

      assert {:ok, device} = fetch_device(realm, device_id, tenant)

      assert %Device{
               online: false,
               last_disconnection: ^timestamp
             } = device
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
      connection_timestamp = utc_now_second() |> DateTime.add(-10, :minute)
      disconnection_timestamp = DateTime.add(connection_timestamp, -40, :minute)

      Edgehog.Astarte.Device.DeviceStatusMock
      |> expect(:get, fn _client, ^device_id ->
        device_status =
          device_status_fixture(
            online: true,
            last_connection: connection_timestamp,
            last_disconnection: disconnection_timestamp
          )

        {:ok, device_status}
      end)

      assert post(conn, path, event) |> response(200)

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
      assert post(conn, path, event) |> response(200)

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

      assert post(conn, path, event) |> response(200)

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

      assert post(conn, path, event) |> response(200)

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

      assert post(conn, path, event) |> response(403)
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
        timestamp: DateTime.utc_now() |> DateTime.to_unix()
      }

      assert post(conn, path, unprocessable_event) |> response(422)
    end

    test "with different tenant does not find realm and returns error", ctx do
      %{
        conn: conn,
        device: %{device_id: device_id}
      } = ctx

      other_tenant = Edgehog.TenantsFixtures.tenant_fixture(slug: "other")
      path = Routes.astarte_trigger_path(conn, :process_event, other_tenant.slug)
      event = connection_trigger(device_id, utc_now_second())

      assert post(conn, path, event) |> response(404)
    end
  end

  describe "process_event/2 for OTA updates" do
    setup %{tenant: tenant} do
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
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
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
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
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
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, ota_event)

      assert response(conn, 200)

      operation = OSManagement.fetch_ota_operation!(ota_operation.id, tenant: tenant)

      assert operation.status_code == nil
    end
  end

  defp fetch_device(realm, device_id, tenant, load \\ []) do
    Device
    |> Ash.get(%{realm_id: realm.id, device_id: device_id}, tenant: tenant, load: load)
  end

  defp utc_now_second do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
  end

  defp connection_trigger(device_id, timestamp) do
    %{
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
      device_id: device_id,
      event: %{
        type: "incoming_data",
        interface: @system_info_interface,
        path: "/partNumber",
        value: part_number
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp serial_number_trigger(device_id, serial_number) do
    %{
      device_id: device_id,
      event: %{
        type: "incoming_data",
        interface: @system_info_interface,
        path: "/serialNumber",
        value: serial_number
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp unknown_trigger(device_id) do
    %{
      device_id: device_id,
      event: %{
        type: "incoming_data",
        interface: "org.example.SomeOtherInterface",
        path: "/foo",
        value: 42
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
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
end
