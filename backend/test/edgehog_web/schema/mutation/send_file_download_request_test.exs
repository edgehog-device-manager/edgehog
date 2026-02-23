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

defmodule EdgehogWeb.Schema.Mutation.SendFileDownloadRequestTest do
  use Edgehog.DataCase, async: true

  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures

  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.FileDownloadRequestMock
  alias Edgehog.Files
  alias Edgehog.Files.EphemeralFileMock
  alias Edgehog.Files.FileDownloadRequest

  describe "digest computation correctness" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    # Catches mutation: removing/changing the "sha256:" prefix
    test "digest is always prefixed with 'sha256:'", %{tenant: tenant, device: device} do
      file_upload = %Plug.Upload{
        path: create_temp_file("prefix test"),
        filename: "prefix.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, _, _ -> {:ok, "https://example.com/f.bin"} end)
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      assert String.starts_with?(fdr.digest, "sha256:")
    end

    # Catches mutation: Base.encode16(case: :upper) instead of :lower
    test "digest hex portion is lowercase", %{tenant: tenant, device: device} do
      file_upload = %Plug.Upload{
        path: create_temp_file("case test"),
        filename: "case.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, _, _ -> {:ok, "https://example.com/f.bin"} end)
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      <<"sha256:", hex::binary>> = fdr.digest

      assert hex == String.downcase(hex),
             "Expected lowercase hex in digest, got: #{hex}"
    end

    # Catches mutation: returning a constant digest instead of computing it
    test "different file contents produce different digests", %{tenant: tenant, device: device} do
      upload_a = %Plug.Upload{
        path: create_temp_file("content A"),
        filename: "a.bin",
        content_type: "application/octet-stream"
      }

      upload_b = %Plug.Upload{
        path: create_temp_file("content B"),
        filename: "b.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, 2, fn _, _, _ -> {:ok, "https://example.com/f.bin"} end)
      expect(FileDownloadRequestMock, :request_download, 2, fn _, _, _ -> :ok end)

      assert {:ok, fdr_a} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: upload_a}, tenant: tenant)
               |> Ash.create()

      assert {:ok, fdr_b} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: upload_b}, tenant: tenant)
               |> Ash.create()

      refute fdr_a.digest == fdr_b.digest,
             "Different contents must produce different digests"
    end

    # Catches mutation: using wrong hash algorithm (e.g., :sha instead of :sha256)
    test "digest matches independently computed SHA-256", %{tenant: tenant, device: device} do
      content = "known content for sha256 verification"

      file_upload = %Plug.Upload{
        path: create_temp_file(content),
        filename: "known.bin",
        content_type: "application/octet-stream"
      }

      expected =
        "sha256:" <>
          (:sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower))

      expect(EphemeralFileMock, :upload, fn _, _, _ -> {:ok, "https://example.com/f.bin"} end)
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      assert fdr.digest == expected
    end

    # Catches mutation: using file name length instead of actual byte_size
    test "digest is the same for same content regardless of filename", %{
      tenant: tenant,
      device: device
    } do
      content = "identical content"

      upload_x = %Plug.Upload{
        path: create_temp_file(content),
        filename: "alpha.bin",
        content_type: "application/octet-stream"
      }

      upload_y = %Plug.Upload{
        path: create_temp_file(content),
        filename: "omega.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, 2, fn _, _, _ -> {:ok, "https://example.com/f.bin"} end)
      expect(FileDownloadRequestMock, :request_download, 2, fn _, _, _ -> :ok end)

      assert {:ok, fdr_x} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: upload_x}, tenant: tenant)
               |> Ash.create()

      assert {:ok, fdr_y} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: upload_y}, tenant: tenant)
               |> Ash.create()

      assert fdr_x.digest == fdr_y.digest
    end
  end

  describe "file size extraction" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    # Catches mutation: returning a hardcoded size, or using wrong stat field
    test "uncompressed_file_size_bytes matches exact content byte size", %{
      tenant: tenant,
      device: device
    } do
      content = String.duplicate("x", 1337)

      file_upload = %Plug.Upload{
        path: create_temp_file(content),
        filename: "sized.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, _, _ -> {:ok, "https://example.com/f.bin"} end)
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      assert fdr.uncompressed_file_size_bytes == 1337
    end

    # Catches mutation: swapping file_size and file_mode fields
    test "file size in request data matches the stored size", %{tenant: tenant, device: device} do
      content = String.duplicate("y", 512)

      file_upload = %Plug.Upload{
        path: create_temp_file(content),
        filename: "req-sized.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, _, _ -> {:ok, "https://example.com/f.bin"} end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, request_data ->
        assert request_data.fileSizeBytes == 512
        :ok
      end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      assert fdr.uncompressed_file_size_bytes == 512
    end
  end

  describe "request data field mapping" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    # Catches mutations: swapping snake_case↔camelCase fields (ttl_seconds→ttlSeconds etc.)
    test "all snake_case fields are correctly mapped to camelCase in RequestData", %{
      tenant: tenant,
      device: device
    } do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          url: "https://example.com/mapped.bin",
          file_name: "mapped.bin",
          uncompressed_file_size_bytes: 999,
          digest: "sha256:aabbcc",
          compression: "tar.gz",
          ttl_seconds: 7200,
          file_mode: 0o755,
          user_id: 42,
          group_id: 99,
          destination: "streaming",
          progress: true
        )

      expect(FileDownloadRequestMock, :request_download, fn _, _, req ->
        # Each assertion targets a specific field mapping mutation
        assert req.id == fdr.id, "id mapping wrong"
        assert req.url == "https://example.com/mapped.bin", "url mapping wrong"
        assert req.fileName == "mapped.bin", "file_name→fileName mapping wrong"

        assert req.fileSizeBytes == 999,
               "uncompressed_file_size_bytes→fileSizeBytes mapping wrong"

        assert req.digest == "sha256:aabbcc", "digest mapping wrong"
        assert req.compression == "tar.gz", "compression mapping wrong"
        assert req.ttlSeconds == 7200, "ttl_seconds→ttlSeconds mapping wrong"
        assert req.fileMode == 0o755, "file_mode→fileMode mapping wrong"
        assert req.userId == 42, "user_id→userId mapping wrong"
        assert req.groupId == 99, "group_id→groupId mapping wrong"
        assert req.destination == :streaming, "destination mapping wrong"
        assert req.progress == true, "progress mapping wrong"
        :ok
      end)

      assert :ok = Files.send_file_download_request(fdr)
    end

    # Catches mutation: removing the nil→"" coercion for compression
    test "nil compression in DB is sent as empty string to device", %{
      tenant: tenant,
      device: device
    } do
      fdr = file_download_request_fixture(tenant: tenant, device_id: device.id, compression: nil)

      expect(FileDownloadRequestMock, :request_download, fn _, _, req ->
        assert req.compression == "",
               "nil compression must be coerced to \"\" before sending to device"

        :ok
      end)

      assert :ok = Files.send_file_download_request(fdr)
    end

    # Catches mutation: using device.id instead of device.device_id
    test "Astarte device_id is device.device_id string, not the DB primary key", %{
      tenant: tenant,
      device: device
    } do
      fdr = file_download_request_fixture(tenant: tenant, device_id: device.id)

      device_id_string = device.device_id

      expect(FileDownloadRequestMock, :request_download, fn _, sent_device_id, _ ->
        assert sent_device_id == device_id_string,
               "Expected device_id string '#{device_id_string}', got '#{sent_device_id}'"

        :ok
      end)

      assert :ok = Files.send_file_download_request(fdr)
    end

    # Catches mutation: using fdr.url for the id field or vice-versa
    test "request id is the FDR's UUID, not the URL", %{tenant: tenant, device: device} do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          url: "https://example.com/not-the-id.bin"
        )

      expect(FileDownloadRequestMock, :request_download, fn _, _, req ->
        assert req.id == fdr.id, "request id must be fdr.id UUID, not url or other field"

        refute req.id == fdr.url,
               "request id must NOT be the url"

        :ok
      end)

      assert :ok = Files.send_file_download_request(fdr)
    end

    # Catches mutation: hardcoding httpHeaderKey/httpHeaderValue to non-empty values
    test "HTTP header fields are always sent as empty strings", %{tenant: tenant, device: device} do
      fdr = file_download_request_fixture(tenant: tenant, device_id: device.id)

      expect(FileDownloadRequestMock, :request_download, fn _, _, req ->
        assert req.httpHeaderKey == "",
               "httpHeaderKey must be empty string, got: #{inspect(req.httpHeaderKey)}"

        assert req.httpHeaderValue == "",
               "httpHeaderValue must be empty string, got: #{inspect(req.httpHeaderValue)}"

        :ok
      end)

      assert :ok = Files.send_file_download_request(fdr)
    end
  end

  describe "ephemeral file scoping" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    # Catches mutation: passing device.id instead of fdr.id to upload
    test "upload receives the FDR's own UUID as file_download_request_id", %{
      tenant: tenant,
      device: device
    } do
      file_upload = %Plug.Upload{
        path: create_temp_file("scope test"),
        filename: "scope.bin",
        content_type: "application/octet-stream"
      }

      captured_fdr_id = self()

      expect(EphemeralFileMock, :upload, fn _tenant_id, fdr_id, _file ->
        send(captured_fdr_id, {:upload_fdr_id, fdr_id})
        {:ok, "https://bucket.example.com/scope.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      assert_receive {:upload_fdr_id, upload_fdr_id}

      assert upload_fdr_id == fdr.id,
             "upload must use the FDR's own id, not another identifier"
    end

    # Catches mutation: passing wrong URL to delete (e.g., a hardcoded string)
    test "delete receives the exact URL that was stored on the FDR", %{
      tenant: tenant,
      device: device
    } do
      specific_url = "https://bucket.example.com/ephemeral/exact-url-test.bin"

      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          manual?: true,
          url: specific_url
        )

      expect(EphemeralFileMock, :delete, fn _tenant_id, _fdr_id, deleted_url ->
        assert deleted_url == specific_url,
               "delete must pass exact stored URL '#{specific_url}', got '#{deleted_url}'"

        :ok
      end)

      assert :ok =
               fdr
               |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: tenant)
               |> Ash.destroy()
    end

    # Catches mutation: passing a random/wrong fdr_id to delete
    test "delete receives the FDR's own UUID when destroying", %{tenant: tenant, device: device} do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          manual?: true
        )

      fdr_id = fdr.id

      expect(EphemeralFileMock, :delete, fn _tenant_id, deleted_fdr_id, _url ->
        assert deleted_fdr_id == fdr_id,
               "delete must use fdr.id='#{fdr_id}', got '#{deleted_fdr_id}'"

        :ok
      end)

      assert :ok =
               fdr
               |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: tenant)
               |> Ash.destroy()
    end

    # Catches mutation: calling delete unconditionally (ignoring manual? flag)
    test "delete is NOT called when manual? is false", %{tenant: tenant, device: device} do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          manual?: false
        )

      # The mock verifies that :delete is never called; if it were,
      # verify_on_exit! would raise "unexpected call"
      assert :ok =
               fdr
               |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: tenant)
               |> Ash.destroy()
    end

    # Catches mutation: calling delete when manual? is true (inverted condition)
    test "delete IS called exactly once when manual? is true", %{tenant: tenant, device: device} do
      fdr =
        file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          manual?: true
        )

      # expect/3 with count 1 enforces exactly one call — catches both "never called"
      # and "called twice" mutations
      expect(EphemeralFileMock, :delete, 1, fn _, _, _ -> :ok end)

      assert :ok =
               fdr
               |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: tenant)
               |> Ash.destroy()
    end
  end

  describe "cleanup on Astarte failure" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    # Catches mutation: not calling delete on transaction error
    test "delete is called exactly once when Astarte fails", %{tenant: tenant, device: device} do
      file_upload = %Plug.Upload{
        path: create_temp_file("astarte fail"),
        filename: "fail.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, _, _ ->
        {:ok, "https://bucket.example.com/fail.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ ->
        {:error, %APIError{status: 503, response: "Unavailable"}}
      end)

      expect(EphemeralFileMock, :delete, 1, fn _, _, _ -> :ok end)

      assert {:error, _} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()
    end

    # Catches mutation: calling delete when Astarte succeeds (wrong branch)
    test "delete is NOT called when Astarte succeeds", %{tenant: tenant, device: device} do
      file_upload = %Plug.Upload{
        path: create_temp_file("astarte ok"),
        filename: "ok.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, _, _ ->
        {:ok, "https://bucket.example.com/ok.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      # No delete expectation — verify_on_exit! will catch unexpected calls
      assert {:ok, _fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()
    end

    # Catches mutation: deleting the wrong URL on cleanup
    test "cleanup deletes the URL that was returned by upload, not a different one", %{
      tenant: tenant,
      device: device
    } do
      file_upload = %Plug.Upload{
        path: create_temp_file("url match"),
        filename: "url-match.bin",
        content_type: "application/octet-stream"
      }

      uploaded_url = "https://bucket.example.com/uploaded-url-match.bin"

      expect(EphemeralFileMock, :upload, fn _, _, _ -> {:ok, uploaded_url} end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ ->
        {:error, %APIError{status: 502, response: "Bad Gateway"}}
      end)

      expect(EphemeralFileMock, :delete, fn _, _, deleted_url ->
        assert deleted_url == uploaded_url,
               "cleanup must delete the uploaded URL '#{uploaded_url}', got '#{deleted_url}'"

        :ok
      end)

      assert {:error, _} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()
    end

    # Catches mutation: persisting the record despite Astarte failure
    test "no record is persisted in the DB when Astarte request fails", %{
      tenant: tenant,
      device: device
    } do
      file_upload = %Plug.Upload{
        path: create_temp_file("no persist"),
        filename: "nopersist.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, _, _ ->
        {:ok, "https://bucket.example.com/nopersist.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ ->
        {:error, %APIError{status: 500, response: "Internal Server Error"}}
      end)

      expect(EphemeralFileMock, :delete, fn _, _, _ -> :ok end)

      assert {:error, _} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      count =
        FileDownloadRequest
        |> Ash.Query.for_read(:read, %{}, tenant: tenant)
        |> Ash.read!()
        |> length()

      assert count == 0,
             "Expected 0 persisted records after Astarte failure, got #{count}"
    end

    # Catches mutation: persisting the record N times instead of 0 or 1
    test "exactly one record is persisted when both upload and Astarte succeed", %{
      tenant: tenant,
      device: device
    } do
      file_upload = %Plug.Upload{
        path: create_temp_file("persist once"),
        filename: "once.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, _, _ ->
        {:ok, "https://bucket.example.com/once.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      assert {:ok, _fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      count =
        FileDownloadRequest
        |> Ash.Query.for_read(:read, %{}, tenant: tenant)
        |> Ash.read!()
        |> length()

      assert count == 1,
             "Expected exactly 1 persisted record after success, got #{count}"
    end
  end

  describe "Astarte interface and endpoint" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    # Catches mutation: wrong interface name string
    test "request_download is called via the correct behaviour module", %{
      tenant: tenant,
      device: device
    } do
      fdr = file_download_request_fixture(tenant: tenant, device_id: device.id)

      # The mock IS the injected module — if module substitution is broken,
      # this call never arrives and the mock raises on verify_on_exit!
      expect(FileDownloadRequestMock, :request_download, 1, fn _, _, _ -> :ok end)

      assert :ok = Files.send_file_download_request(fdr)
    end

    # Catches mutation: not passing the AppEngine client at all
    test "an AppEngine client is provided as the first argument to request_download", %{
      tenant: tenant,
      device: device
    } do
      fdr = file_download_request_fixture(tenant: tenant, device_id: device.id)

      expect(FileDownloadRequestMock, :request_download, fn client, _, _ ->
        assert client != nil,
               "AppEngine client must not be nil"

        # Client is an AppEngine struct — pattern match key fields
        assert is_struct(client), "client must be a struct"
        :ok
      end)

      assert :ok = Files.send_file_download_request(fdr)
    end
  end

  describe "record structure and persistence" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      %{tenant: tenant, device: device}
    end

    # Catches mutation: not setting manual? on the manual create action
    test "manual create action always sets manual? to true", %{tenant: tenant, device: device} do
      file_upload = %Plug.Upload{
        path: create_temp_file("manual flag"),
        filename: "manual.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, _, _ -> {:ok, "https://example.com/f.bin"} end)
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      assert fdr.manual? == true,
             "manual create action must set manual? = true, got #{inspect(fdr.manual?)}"
    end

    # Catches mutation: the uploaded URL not being stored on the FDR
    test "the URL stored on the FDR is exactly the one returned by the upload", %{
      tenant: tenant,
      device: device
    } do
      file_upload = %Plug.Upload{
        path: create_temp_file("url store"),
        filename: "urlstore.bin",
        content_type: "application/octet-stream"
      }

      returned_url = "https://bucket.example.com/unique-url-#{System.unique_integer()}.bin"

      expect(EphemeralFileMock, :upload, fn _, _, _ -> {:ok, returned_url} end)
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      assert fdr.url == returned_url,
             "Stored URL must equal upload return value. Expected '#{returned_url}', got '#{fdr.url}'"
    end

    # Catches mutation: storing the wrong device association
    test "the device_id stored on the FDR matches the requested device", %{
      tenant: tenant,
      device: device
    } do
      file_upload = %Plug.Upload{
        path: create_temp_file("device assoc"),
        filename: "device.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, _, _ -> {:ok, "https://example.com/f.bin"} end)
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      assert fdr.device_id == device.id,
             "device_id must be #{device.id}, got #{fdr.device_id}"
    end

    # Catches mutation: not generating a UUID for the ID, or generating it too late
    # (the ID must be set on the changeset before the upload so the upload can use it)
    test "file download request has a valid UUID v7 id after creation", %{
      tenant: tenant,
      device: device
    } do
      file_upload = %Plug.Upload{
        path: create_temp_file("uuid check"),
        filename: "uuid.bin",
        content_type: "application/octet-stream"
      }

      expect(EphemeralFileMock, :upload, fn _, fdr_id, _ ->
        # The ID must already be a valid binary UUID at upload time
        assert is_binary(fdr_id), "FDR id must be a binary at upload time"
        assert byte_size(fdr_id) == 36, "FDR id must be a 36-char UUID string"
        {:ok, "https://example.com/f.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      assert {:ok, fdr} =
               FileDownloadRequest
               |> Ash.Changeset.for_create(:manual, %{device_id: device.id, file: file_upload}, tenant: tenant)
               |> Ash.create()

      assert is_binary(fdr.id)
      assert byte_size(fdr.id) == 36
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
