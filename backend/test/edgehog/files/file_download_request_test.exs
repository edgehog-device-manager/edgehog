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

defmodule Edgehog.Files.FileDownloadRequestTest do
  use Edgehog.DataCase, async: true

  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures

  alias Ash.Error.Invalid
  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.FileDownloadRequestMock
  alias Edgehog.Error.AstarteAPIError
  alias Edgehog.Files
  alias Edgehog.Files.EphemeralFileMock
  alias Edgehog.Files.FileDownloadRequest

  describe "FileDownloadRequest create via fixture" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "creates a file download request with generated defaults", %{
      tenant: tenant,
      device: device
    } do
      fdr = file_download_request_fixture(tenant: tenant, device_id: device.id)

      assert %FileDownloadRequest{} = fdr
      assert fdr.url =~ "https://example.com/ephemeral/"
      assert fdr.file_name =~ "file-"
      assert fdr.uncompressed_file_size_bytes > 0
      assert fdr.digest =~ "sha256:"
      assert fdr.ttl_seconds == 0
      assert is_integer(fdr.file_mode)
      assert is_integer(fdr.user_id)
      assert is_integer(fdr.group_id)
      assert fdr.destination == :storage
      assert fdr.progress == false
      assert fdr.manual? == true
      assert fdr.device_id == device.id
    end

    test "creates a file download request with custom attributes", %{
      tenant: tenant,
      device: device
    } do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          url: "https://my-bucket.s3.amazonaws.com/custom-file.tar.gz",
          file_name: "custom-firmware.tar.gz",
          uncompressed_file_size_bytes: 54_321,
          digest: "sha256:deadbeef",
          compression: "tar.gz",
          ttl_seconds: 3600,
          file_mode: 0o755,
          user_id: 1000,
          group_id: 1000,
          destination: "streaming",
          progress: true,
          manual?: false
        )

      assert fdr.url == "https://my-bucket.s3.amazonaws.com/custom-file.tar.gz"
      assert fdr.file_name == "custom-firmware.tar.gz"
      assert fdr.uncompressed_file_size_bytes == 54_321
      assert fdr.digest == "sha256:deadbeef"
      assert fdr.compression == "tar.gz"
      assert fdr.ttl_seconds == 3600
      assert fdr.file_mode == 0o755
      assert fdr.user_id == 1000
      assert fdr.group_id == 1000
      assert fdr.destination == :streaming
      assert fdr.progress == true
      assert fdr.manual? == false
    end

    test "auto-creates device when device_id not provided", %{tenant: tenant} do
      fdr = file_download_request_fixture(tenant: tenant)
      assert %FileDownloadRequest{} = fdr
      assert fdr.device_id
    end

    test "creates a fixture with specific status values", %{tenant: tenant, device: device} do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :sent,
          status_progress: 50,
          status_code: 0,
          message: "Transfer in progress"
        )

      assert fdr.status == :sent
      assert fdr.status_progress == 50
      assert fdr.status_code == 0
      assert fdr.message == "Transfer in progress"
    end
  end

  describe "FileDownloadRequest.Status" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "supports all status lifecycle values", %{tenant: tenant, device: device} do
      for status <- [:pending, :sent, :in_progress, :completed, :failed] do
        fdr =
          file_download_request_fixture(
            tenant: tenant,
            device_id: device.id,
            status: status
          )

        assert fdr.status == status
      end
    end
  end

  describe "FileDownloadRequest.FileDestination" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "supports storage destination", %{tenant: tenant, device: device} do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          destination: "storage"
        )

      assert fdr.destination == :storage
    end

    test "supports streaming destination", %{tenant: tenant, device: device} do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          destination: "streaming"
        )

      assert fdr.destination == :streaming
    end
  end

  describe "manual create action" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "creates a file download request with file upload and sends to device", %{
      tenant: tenant,
      device: device
    } do
      file_upload = %Plug.Upload{
        path: create_temp_file("hello world"),
        filename: "test-firmware.bin",
        content_type: "application/octet-stream"
      }

      uploaded_url = "https://bucket.example.com/ephemeral/test-firmware.bin"

      expect(EphemeralFileMock, :upload, fn tenant_id, fdr_id, ^file_upload ->
        assert tenant_id
        assert is_binary(fdr_id)
        {:ok, uploaded_url}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _client, device_id, request_data ->
        assert device_id == device.device_id
        assert request_data.url == uploaded_url
        assert request_data.fileName == "test-firmware.bin"
        assert request_data.progress == false
        assert request_data.compression == ""
        assert request_data.destination == :storage
        :ok
      end)

      assert {:ok, %FileDownloadRequest{} = fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{device_id: device.id, file: file_upload},
                 tenant: tenant
               )
               |> Ash.create()

      assert fdr.url == uploaded_url
      assert fdr.file_name == "test-firmware.bin"
      assert fdr.manual? == true
      assert fdr.device_id == device.id
      assert fdr.uncompressed_file_size_bytes > 0
      assert fdr.digest =~ "sha256:"
    end

    test "creates a file download request with custom options", %{
      tenant: tenant,
      device: device
    } do
      file_upload = %Plug.Upload{
        path: create_temp_file("compressed content"),
        filename: "archive.tar.gz",
        content_type: "application/gzip"
      }

      uploaded_url = "https://bucket.example.com/ephemeral/archive.tar.gz"

      expect(EphemeralFileMock, :upload, fn _tenant_id, _fdr_id, ^file_upload ->
        {:ok, uploaded_url}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _client, _device_id, request_data ->
        assert request_data.compression == "tar.gz"
        assert request_data.ttlSeconds == 7200
        assert request_data.destination == :streaming
        assert request_data.progress == true
        :ok
      end)

      assert {:ok, %FileDownloadRequest{} = fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{
                   device_id: device.id,
                   file: file_upload,
                   compression: "tar.gz",
                   ttl_seconds: 7200,
                   destination: "streaming",
                   progress: true
                 },
                 tenant: tenant
               )
               |> Ash.create()

      assert fdr.compression == "tar.gz"
      assert fdr.ttl_seconds == 7200
      assert fdr.destination == :streaming
      assert fdr.progress == true
    end

    test "fails when device does not exist", %{tenant: tenant} do
      non_existent_device_id = Ash.UUIDv7.generate()

      file_upload = %Plug.Upload{
        path: create_temp_file("content"),
        filename: "test.bin",
        content_type: "application/octet-stream"
      }

      assert {:error, %Invalid{}} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{device_id: non_existent_device_id, file: file_upload},
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "fails when device_id is not provided", %{tenant: tenant} do
      file_upload = %Plug.Upload{
        path: create_temp_file("content"),
        filename: "test.bin",
        content_type: "application/octet-stream"
      }

      assert {:error, %Invalid{}} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{file: file_upload},
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "cleans up uploaded file when Astarte request fails", %{
      tenant: tenant,
      device: device
    } do
      file_upload = %Plug.Upload{
        path: create_temp_file("cleanup test"),
        filename: "cleanup-test.bin",
        content_type: "application/octet-stream"
      }

      uploaded_url = "https://bucket.example.com/ephemeral/cleanup-test.bin"

      expect(EphemeralFileMock, :upload, fn _tenant_id, _fdr_id, ^file_upload ->
        {:ok, uploaded_url}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _client, _device_id, _request_data ->
        {:error, %APIError{status: 503, response: "Cannot push to device"}}
      end)

      expect(EphemeralFileMock, :delete, fn _tenant_id, _fdr_id, ^uploaded_url ->
        :ok
      end)

      assert {:error, %Invalid{errors: errors}} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{device_id: device.id, file: file_upload},
                 tenant: tenant
               )
               |> Ash.create()

      assert [%AstarteAPIError{status: 503, response: "Cannot push to device"}] = errors
    end

    test "fails when file upload fails", %{tenant: tenant, device: device} do
      file_upload = %Plug.Upload{
        path: create_temp_file("upload fail"),
        filename: "fail.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _tenant_id, _fdr_id, ^file_upload ->
        {:error, :storage_unavailable}
      end)

      assert {:error, %Invalid{}} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{device_id: device.id, file: file_upload},
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "computes digest from file content", %{tenant: tenant, device: device} do
      content = "deterministic content for digest"

      file_upload = %Plug.Upload{
        path: create_temp_file(content),
        filename: "digest-test.bin",
        content_type: "application/octet-stream"
      }

      expected_hash =
        :sha256
        |> :crypto.hash(content)
        |> Base.encode16(case: :lower)

      expected_digest = "sha256:#{expected_hash}"

      expect(EphemeralFileMock, :upload, fn _tenant_id, _fdr_id, _file ->
        {:ok, "https://bucket.example.com/file.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _client, _device_id, request_data ->
        assert request_data.digest == expected_digest
        :ok
      end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{device_id: device.id, file: file_upload},
                 tenant: tenant
               )
               |> Ash.create()

      assert fdr.digest == expected_digest
    end

    test "extracts file metadata (size, mode, uid, gid) from uploaded file", %{
      tenant: tenant,
      device: device
    } do
      content = "metadata test content"

      file_upload = %Plug.Upload{
        path: create_temp_file(content),
        filename: "metadata-test.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _tenant_id, _fdr_id, _file ->
        {:ok, "https://bucket.example.com/metadata.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _client, _device_id, _request_data ->
        :ok
      end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{device_id: device.id, file: file_upload},
                 tenant: tenant
               )
               |> Ash.create()

      assert fdr.uncompressed_file_size_bytes == byte_size(content)
      assert is_integer(fdr.file_mode)
      assert is_integer(fdr.user_id)
      assert is_integer(fdr.group_id)
    end
  end

  describe "send_file_download_request" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "succeeds when Astarte request succeeds", %{tenant: tenant, device: device} do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          compression: "tar.gz"
        )

      device_id = device.device_id
      fdr_id = fdr.id

      expect(FileDownloadRequestMock, :request_download, fn _client, ^device_id, request_data ->
        assert request_data.id == fdr_id
        assert request_data.url == fdr.url
        assert request_data.fileName == fdr.file_name
        assert request_data.compression == "tar.gz"
        assert request_data.fileSizeBytes == fdr.uncompressed_file_size_bytes
        assert request_data.progress == fdr.progress
        assert request_data.digest == fdr.digest
        assert request_data.ttlSeconds == fdr.ttl_seconds
        assert request_data.fileMode == fdr.file_mode
        assert request_data.userId == fdr.user_id
        assert request_data.groupId == fdr.group_id
        assert request_data.destination == fdr.destination
        assert request_data.httpHeaderKey == ""
        assert request_data.httpHeaderValue == ""
        :ok
      end)

      assert :ok = Files.send_file_download_request(fdr)
    end

    test "fails when Astarte request fails", %{tenant: tenant, device: device} do
      fdr = file_download_request_fixture(tenant: tenant, device_id: device.id)

      expect(FileDownloadRequestMock, :request_download, fn _client, _device_id, _request_data ->
        {:error, %APIError{status: 503, response: "Cannot push to device"}}
      end)

      assert {:error, %Invalid{errors: errors}} =
               Files.send_file_download_request(fdr)

      assert [%AstarteAPIError{status: 503, response: "Cannot push to device"}] = errors
    end

    test "sends correct request data for streaming destination", %{
      tenant: tenant,
      device: device
    } do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          destination: "streaming",
          compression: "tar.gz",
          ttl_seconds: 3600,
          progress: true
        )

      expect(FileDownloadRequestMock, :request_download, fn _client, _device_id, request_data ->
        assert request_data.destination == :streaming
        assert request_data.compression == "tar.gz"
        assert request_data.ttlSeconds == 3600
        assert request_data.progress == true
        :ok
      end)

      assert :ok = Files.send_file_download_request(fdr)
    end

    test "maps nil compression to empty string in request data", %{
      tenant: tenant,
      device: device
    } do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          compression: nil
        )

      expect(FileDownloadRequestMock, :request_download, fn _client, _device_id, request_data ->
        # nil compression should be converted to ""
        assert request_data.compression == ""
        :ok
      end)

      assert :ok = Files.send_file_download_request(fdr)
    end
  end

  describe "destroy action" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "destroys a manual file download request and cleans up ephemeral file", %{
      tenant: tenant,
      device: device
    } do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          manual?: true
        )

      fdr_id = fdr.id
      fdr_url = fdr.url

      expect(EphemeralFileMock, :delete, fn _tenant_id, ^fdr_id, ^fdr_url ->
        :ok
      end)

      assert :ok =
               fdr
               |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: tenant)
               |> Ash.destroy()
    end

    test "destroys a non-manual file download request without ephemeral cleanup", %{
      tenant: tenant,
      device: device
    } do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          manual?: false
        )

      # No EphemeralFileMock expectation — it should NOT be called for non-manual requests
      assert :ok =
               fdr
               |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: tenant)
               |> Ash.destroy()
    end

    test "destroy still succeeds if ephemeral file cleanup fails", %{
      tenant: tenant,
      device: device
    } do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          manual?: true
        )

      expect(EphemeralFileMock, :delete, fn _tenant_id, _fdr_id, _url ->
        {:error, :storage_unavailable}
      end)

      # Destroy should not fail even if cleanup fails — it's best effort
      assert :ok =
               fdr
               |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: tenant)
               |> Ash.destroy()
    end
  end

  describe "destroy_fixture action" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "destroys without ephemeral cleanup even for manual requests", %{
      tenant: tenant,
      device: device
    } do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          manual?: true
        )

      # No mock expectations — destroy_fixture should not trigger cleanup
      assert :ok =
               fdr
               |> Ash.Changeset.for_destroy(:destroy_fixture, %{}, tenant: tenant)
               |> Ash.destroy()
    end
  end

  describe "read action" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "reads all file download requests", %{tenant: tenant, device: device} do
      fdr1 = file_download_request_fixture(tenant: tenant, device_id: device.id)
      fdr2 = file_download_request_fixture(tenant: tenant, device_id: device.id)

      results =
        FileDownloadRequest
        |> Ash.Query.for_read(:read, %{}, tenant: tenant)
        |> Ash.read!()

      result_ids = Enum.map(results, & &1.id)
      assert fdr1.id in result_ids
      assert fdr2.id in result_ids
    end

    test "reads a specific file download request by id", %{tenant: tenant, device: device} do
      fdr = file_download_request_fixture(tenant: tenant, device_id: device.id)

      result = Ash.get!(FileDownloadRequest, fdr.id, tenant: tenant)
      assert result.id == fdr.id
      assert result.url == fdr.url
    end
  end

  describe "device relationship" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "belongs to a device", %{tenant: tenant, device: device} do
      fdr = file_download_request_fixture(tenant: tenant, device_id: device.id)
      fdr_with_device = Ash.load!(fdr, :device, tenant: tenant)

      assert fdr_with_device.device.id == device.id
    end

    test "device has_many file_download_requests", %{tenant: tenant, device: device} do
      fdr1 = file_download_request_fixture(tenant: tenant, device_id: device.id)
      fdr2 = file_download_request_fixture(tenant: tenant, device_id: device.id)

      device_with_fdrs = Ash.load!(device, :file_download_requests, tenant: tenant)
      fdr_ids = Enum.map(device_with_fdrs.file_download_requests, & &1.id)

      assert fdr1.id in fdr_ids
      assert fdr2.id in fdr_ids
    end

    test "file download requests are scoped to their device", %{tenant: tenant} do
      device1 = device_fixture(tenant: tenant)
      device2 = device_fixture(tenant: tenant)

      fdr1 = file_download_request_fixture(tenant: tenant, device_id: device1.id)
      _fdr2 = file_download_request_fixture(tenant: tenant, device_id: device2.id)

      device1_with_fdrs = Ash.load!(device1, :file_download_requests, tenant: tenant)
      fdr_ids = Enum.map(device1_with_fdrs.file_download_requests, & &1.id)

      assert fdr1.id in fdr_ids
      assert length(fdr_ids) == 1
    end
  end

  describe "HandleEphemeralFileUpload" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "sets url, file_name, digest, and file metadata from uploaded file", %{
      tenant: tenant,
      device: device
    } do
      content = "test file content for upload"

      file_upload = %Plug.Upload{
        path: create_temp_file(content),
        filename: "uploaded-file.bin",
        content_type: "application/octet-stream"
      }

      uploaded_url = "https://bucket.example.com/uploads/uploaded-file.bin"

      expect(EphemeralFileMock, :upload, fn _tenant_id, _fdr_id, _file ->
        {:ok, uploaded_url}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _client, _device_id, _data ->
        :ok
      end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{device_id: device.id, file: file_upload},
                 tenant: tenant
               )
               |> Ash.create()

      assert fdr.url == uploaded_url
      assert fdr.file_name == "uploaded-file.bin"
      assert fdr.uncompressed_file_size_bytes == byte_size(content)
      assert fdr.digest =~ "sha256:"
    end

    test "skips upload when no file argument provided", %{tenant: tenant, device: device} do
      # When no file is provided, the manual action should still fail because url is required
      # but the upload step should be skipped

      assert {:error, %Invalid{}} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{device_id: device.id},
                 tenant: tenant
               )
               |> Ash.create()
    end
  end

  describe "HandleEphemeralFileDeletion" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "calls delete on ephemeral file module for manual requests", %{
      tenant: tenant,
      device: device
    } do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          manual?: true,
          url: "https://bucket.example.com/ephemeral/to-delete.bin"
        )

      fdr_id = fdr.id

      expect(EphemeralFileMock, :delete, fn _tenant_id, ^fdr_id, url ->
        assert url == "https://bucket.example.com/ephemeral/to-delete.bin"
        :ok
      end)

      assert :ok =
               fdr
               |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: tenant)
               |> Ash.destroy()
    end

    test "does not call delete for non-manual requests", %{tenant: tenant, device: device} do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          manual?: false
        )

      # No EphemeralFileMock expectation
      assert :ok =
               fdr
               |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: tenant)
               |> Ash.destroy()
    end
  end

  describe "SendFileDownloadRequest change" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    test "sends request to device after creation", %{tenant: tenant, device: device} do
      file_upload = %Plug.Upload{
        path: create_temp_file("some content"),
        filename: "send-test.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _tenant_id, _fdr_id, _file ->
        {:ok, "https://bucket.example.com/file.bin"}
      end)

      send_called = self()

      expect(FileDownloadRequestMock, :request_download, fn _client, _device_id, _request_data ->
        send(send_called, :request_download_called)
        :ok
      end)

      assert {:ok, _fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{device_id: device.id, file: file_upload},
                 tenant: tenant
               )
               |> Ash.create()

      assert_receive :request_download_called
    end

    test "rolls back creation when Astarte send fails", %{tenant: tenant, device: device} do
      file_upload = %Plug.Upload{
        path: create_temp_file("rollback content"),
        filename: "rollback-test.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _tenant_id, _fdr_id, _file ->
        {:ok, "https://bucket.example.com/rollback.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _client, _device_id, _request_data ->
        {:error, %APIError{status: 500, response: "Internal Server Error"}}
      end)

      expect(EphemeralFileMock, :delete, fn _tenant_id, _fdr_id, _url ->
        :ok
      end)

      assert {:error, %Invalid{}} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(
                 :manual,
                 %{device_id: device.id, file: file_upload},
                 tenant: tenant
               )
               |> Ash.create()

      # Verify the record was not persisted
      results =
        FileDownloadRequest
        |> Ash.Query.for_read(:read, %{}, tenant: tenant)
        |> Ash.read!()

      assert Enum.empty?(results)
    end
  end

  describe "multitenancy" do
    test "file download requests are isolated per tenant" do
      tenant1 = tenant_fixture()
      tenant2 = tenant_fixture()
      device1 = device_fixture(tenant: tenant1)
      device2 = device_fixture(tenant: tenant2)

      fdr1 = file_download_request_fixture(tenant: tenant1, device_id: device1.id)
      _fdr2 = file_download_request_fixture(tenant: tenant2, device_id: device2.id)

      results =
        FileDownloadRequest
        |> Ash.Query.for_read(:read, %{}, tenant: tenant1)
        |> Ash.read!()

      result_ids = Enum.map(results, & &1.id)
      assert fdr1.id in result_ids
      assert length(result_ids) == 1
    end
  end

  # Helpers

  defp create_temp_file(content) do
    path = Path.join(System.tmp_dir!(), "test_upload_#{System.unique_integer([:positive])}.bin")
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
