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

defmodule EdgehogWeb.Controllers.AstarteTriggerController.OtaUpdatesTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.OSManagementFixtures

  alias Edgehog.OSManagement

  require Ash.Query

  describe "process_event/2 for OTA updates" do
    setup %{tenant: tenant} do
      # Some events might trigger an ephemeral image deletion
      stub(Edgehog.OSManagement.EphemeralImageMock, :delete, fn _tenant_id,
                                                                _ota_operation_id,
                                                                _url ->
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
end
