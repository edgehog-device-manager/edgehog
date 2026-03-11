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
  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures

  alias Edgehog.Files.FileDownloadRequest
  alias Edgehog.Files.FileUploadRequest
  alias Edgehog.StorageMock

  describe "process_event/2 for file transfer events" do
    setup %{tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
      device = device_fixture(realm_id: realm.id, tenant: tenant)

      {:ok, cluster: cluster, realm: realm, device: device}
    end

    test "updates file download request status from fileTransfer.Response to completed",
         context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      file_download_request =
        manual_file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :pending
        )

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      expect(StorageMock, :delete, 1, fn _ ->
        :ok
      end)

      response_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.fileTransfer.Response",
          path: "/request",
          value: %{
            "type" => "server_to_device",
            "id" => file_download_request.id,
            "code" => 0,
            "message" => "transfer complete"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, response_event)
      |> response(200)

      request = Ash.get!(FileDownloadRequest, file_download_request.id, tenant: tenant)
      assert request.status == :completed
      assert request.response_code == 0
      assert request.response_message == "transfer complete"
    end

    test "updates file download request status from fileTransfer.Response to failed", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      file_download_request =
        manual_file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :pending
        )

      expect(StorageMock, :delete, 1, fn _ ->
        :ok
      end)

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      response_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.fileTransfer.Response",
          path: "/request",
          value: %{
            "type" => "server_to_device",
            "id" => file_download_request.id,
            "code" => 17,
            "message" => "File exists"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, response_event)
      |> response(200)

      request = Ash.get!(FileDownloadRequest, file_download_request.id, tenant: tenant)
      assert request.status == :failed
      assert request.response_code == 17
      assert request.response_message == "File exists"
    end

    test "updates file download request progress from fileTransfer.Progress", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      file_download_request =
        manual_file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :sent
        )

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      progress_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.fileTransfer.Progress",
          path: "/request",
          value: %{
            "type" => "server_to_device",
            "id" => file_download_request.id,
            "progress" => 80
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, progress_event)
      |> response(200)

      request = Ash.get!(FileDownloadRequest, file_download_request.id, tenant: tenant)
      assert request.status == :in_progress
      assert request.progress_percentage == 80
    end

    test "updates file upload request progress from fileTransfer.Progress", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      file_upload_request =
        file_upload_request_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :sent
        )

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      progress_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.fileTransfer.Progress",
          path: "/request",
          value: %{
            "type" => "device_to_server",
            "id" => file_upload_request.id,
            "progress" => 42
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, progress_event)
      |> response(200)

      request = Ash.get!(FileUploadRequest, file_upload_request.id, tenant: tenant)
      assert request.status == :in_progress
      assert request.progress_percentage == 42
    end

    test "marks file upload request as completed when fileTransfer.Progress reaches 100",
         context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      file_upload_request =
        file_upload_request_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :sent
        )

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      progress_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.fileTransfer.Progress",
          path: "/request",
          value: %{
            "type" => "device_to_server",
            "id" => file_upload_request.id,
            "progress" => 100
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, progress_event)
      |> response(200)

      request = Ash.get!(FileUploadRequest, file_upload_request.id, tenant: tenant)
      assert request.status == :completed
      assert request.progress_percentage == 100
    end

    test "updates file upload request status from fileTransfer.Response to completed", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      file_upload_request =
        file_upload_request_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :sent
        )

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      response_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.fileTransfer.Response",
          path: "/request",
          value: %{
            "type" => "device_to_server",
            "id" => file_upload_request.id,
            "code" => 0,
            "message" => "completed"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, response_event)
      |> response(200)

      request = Ash.get!(FileUploadRequest, file_upload_request.id, tenant: tenant)
      assert request.status == :completed
      assert request.response_code == 0
      assert request.response_message == "completed"
    end

    test "updates file upload request status from fileTransfer.Response to failed", context do
      %{conn: conn, realm: realm, device: device, tenant: tenant} = context

      file_upload_request =
        file_upload_request_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :sent
        )

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      response_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.fileTransfer.Response",
          path: "/request",
          value: %{
            "type" => "device_to_server",
            "id" => file_upload_request.id,
            "code" => 17,
            "message" => "upload failed"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, response_event)
      |> response(200)

      request = Ash.get!(FileUploadRequest, file_upload_request.id, tenant: tenant)
      assert request.status == :failed
      assert request.response_code == 17
      assert request.response_message == "upload failed"
    end
  end
end
