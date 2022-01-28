#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule EdgehogWeb.Controllers.AstarteTriggerControllerTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase
  use Edgehog.EphemeralImageMockCase

  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device
  alias Edgehog.OSManagement

  import Edgehog.AstarteFixtures
  import Edgehog.AppliancesFixtures
  import Edgehog.OSManagementFixtures

  @appliance_info_interface "io.edgehog.devicemanager.ApplianceInfo"

  describe "process_event" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)
      device = device_fixture(realm)

      {:ok, cluster: cluster, realm: realm, device: device}
    end

    test "creates an unexisting device when receiving a connection event", %{
      conn: conn,
      realm: realm,
      tenant: %{slug: tenant_slug}
    } do
      device_id = "JCr8Q5F-QmyaEu19mUW9qw"

      assert {:error, :device_not_found} == Astarte.fetch_realm_device(realm, device_id)

      path = Routes.astarte_trigger_path(conn, :process_event, tenant_slug)

      connection_event = %{
        device_id: device_id,
        event: %{
          type: "device_connected"
        },
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, connection_event)

      assert response(conn, 200)

      assert {:ok, %Device{online: true}} = Astarte.fetch_realm_device(realm, device_id)
    end

    test "updates an existing device when receiving a connection event", %{
      conn: conn,
      realm: realm,
      device: %{device_id: device_id},
      tenant: %{slug: tenant_slug}
    } do
      assert {:ok, %Device{online: false}} = Astarte.fetch_realm_device(realm, device_id)

      path = Routes.astarte_trigger_path(conn, :process_event, tenant_slug)

      connection_event = %{
        device_id: device_id,
        event: %{
          type: "device_connected"
        },
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, connection_event)

      assert response(conn, 200)

      assert {:ok, %Device{online: true}} = Astarte.fetch_realm_device(realm, device_id)
    end

    test "creates an unexisting device when receiving an unhandled event", %{
      conn: conn,
      realm: realm,
      tenant: %{slug: tenant_slug}
    } do
      device_id = "JCr8Q5F-QmyaEu19mUW9qw"

      assert {:error, :device_not_found} == Astarte.fetch_realm_device(realm, device_id)

      path = Routes.astarte_trigger_path(conn, :process_event, tenant_slug)

      connection_event = %{
        device_id: device_id,
        event: %{
          type: "unhandled_event"
        },
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, connection_event)

      assert response(conn, 200)

      assert {:ok, %Device{online: false}} = Astarte.fetch_realm_device(realm, device_id)
    end

    test "updates an existing device when receiving serial number", %{
      conn: conn,
      realm: realm,
      device: %{device_id: device_id},
      tenant: %{slug: tenant_slug}
    } do
      path = Routes.astarte_trigger_path(conn, :process_event, tenant_slug)

      connection_event = %{
        device_id: device_id,
        event: %{
          type: "incoming_data",
          interface: @appliance_info_interface,
          path: "/serialNumber",
          value: "12345"
        },
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, connection_event)

      assert response(conn, 200)

      assert {:ok, %Device{serial_number: "12345"}} = Astarte.fetch_realm_device(realm, device_id)
    end

    test "associates a device with an appliance model when receiving part number", %{
      conn: conn,
      realm: realm,
      device: %{device_id: device_id},
      tenant: %{slug: tenant_slug}
    } do
      hardware_type = hardware_type_fixture()
      appliance_model = appliance_model_fixture(hardware_type)
      [%{part_number: part_number}] = appliance_model.part_numbers

      path = Routes.astarte_trigger_path(conn, :process_event, tenant_slug)

      connection_event = %{
        device_id: device_id,
        event: %{
          type: "incoming_data",
          interface: @appliance_info_interface,
          path: "/partNumber",
          value: part_number
        },
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, connection_event)

      assert response(conn, 200)

      assert {:ok, %Device{} = device} = Astarte.fetch_realm_device(realm, device_id)
      device = Astarte.preload_appliance_model_for_device(device)
      assert device.appliance_model.id == appliance_model.id
      assert device.appliance_model.name == appliance_model.name
      assert device.appliance_model.handle == appliance_model.handle
    end

    test "updates the OTA operation when receiving an event on the OTAResponse interface", %{
      conn: conn,
      realm: realm,
      device: device,
      tenant: %{slug: tenant_slug}
    } do
      ota_operation = manual_ota_operation_fixture(device)

      path = Routes.astarte_trigger_path(conn, :process_event, tenant_slug)

      ota_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.OTAResponse",
          path: "/response",
          value: %{
            uuid: ota_operation.id,
            status: "InProgress",
            statusCode: "SomeCode"
          }
        },
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      conn =
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, ota_event)

      assert response(conn, 200)

      operation = OSManagement.get_ota_operation!(ota_operation.id)

      assert operation.status == :in_progress
      assert operation.status_code == "SomeCode"
    end
  end
end
