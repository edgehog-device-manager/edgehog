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

defmodule EdgehogWeb.Schema.Mutation.CreateFileDownloadRequestTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures

  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.FileDownloadRequestMock
  alias Edgehog.Astarte.Device.FileTransferCapabilities
  alias Edgehog.Astarte.Device.FileTransferCapabilitiesMock
  alias Edgehog.Files.EphemeralFileMock
  alias Edgehog.StorageMock

  setup do
    stub(FileTransferCapabilitiesMock, :get, fn _client, _device_id ->
      {:ok,
       %FileTransferCapabilities{
         encodings: [],
         unix_permissions: false,
         targets: [:filesystem]
       }}
    end)

    :ok
  end

  describe "createManualFileDownloadRequest mutation" do
    setup do
      tmp_path = build_temp_file!("test.bin", "test file content")

      upload = plug_upload(tmp_path, "test.bin")

      %{upload: upload, tmp_path: tmp_path}
    end

    test "creates file download request with all fields", %{
      tenant: tenant,
      upload: upload,
      tmp_path: tmp_path
    } do
      expect(EphemeralFileMock, :upload, fn _, _, _ ->
        {:ok, "https://example.com/test.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      result =
        create_manual_file_download_request_mutation(
          tenant: tenant,
          file: upload
        )

      expected_hash =
        tmp_path
        |> File.stream!(2048)
        |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
        |> :crypto.hash_final()
        |> Base.encode16(case: :lower)

      file_download_request =
        extract_result!(result, "createManualFileDownloadRequest")

      assert file_download_request["id"] != "019c997a-49bc-7f65-be73-0970557338b3"
      assert file_download_request["url"] == "https://example.com/test.bin"
      assert file_download_request["destinationType"] == "STORAGE"
      assert file_download_request["destination"] == nil
      assert file_download_request["progressTracked"] == false
      assert file_download_request["ttlSeconds"] == 100_000
      assert file_download_request["fileName"] == "filename"
      assert file_download_request["uncompressedFileSizeBytes"] == 75_555
      assert file_download_request["digest"] == "sha256:#{expected_hash}"
      assert file_download_request["encoding"] == nil
      assert file_download_request["userId"] == 45
      assert file_download_request["groupId"] == 55

      assert file_download_request["device"]["deviceId"]
    end

    test "returns error when device does not exist", %{tenant: tenant} do
      result =
        create_manual_file_download_request_mutation(
          tenant: tenant,
          device_id: "ZGV2aWNlOjEyMzQ="
        )

      assert %{message: "could not be found"} =
               extract_error!(result, "createManualFileDownloadRequest")
    end

    test "fails if Astarte API returns error", %{tenant: tenant, upload: upload} do
      expect(EphemeralFileMock, :upload, fn _, _, _ ->
        {:ok, "https://example.com/f.bin"}
      end)

      expect(EphemeralFileMock, :delete, fn _, _, _ ->
        {:ok, "https://example.com/f.bin"}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ ->
        {:error, %APIError{status: 500, response: "Internal Server Error"}}
      end)

      result =
        create_manual_file_download_request_mutation(
          tenant: tenant,
          file: upload
        )

      assert %{code: "astarte_api_error", short_message: "Astarte API Error (status 500)"} =
               extract_error!(result, "createManualFileDownloadRequest")
    end

    test "fails if unsupported encoding is passed", %{tenant: tenant, upload: upload} do
      result =
        create_manual_file_download_request_mutation(
          tenant: tenant,
          file: upload,
          encoding: "gz"
        )

      assert %{short_message: "Encoding type not supported by device"} =
               extract_error!(result, "createManualFileDownloadRequest")
    end
  end

  describe "createManagedFileDownloadRequest mutation" do
    test "creates managed file download request from file", %{tenant: tenant} do
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      file = file_fixture(tenant: tenant, name: "managed.bin")

      result =
        create_managed_file_download_request_mutation(
          tenant: tenant,
          file_id: AshGraphql.Resource.encode_relay_id(file)
        )

      file_download_request =
        extract_result!(result, "createManagedFileDownloadRequest")

      assert file_download_request["id"] != "019c997a-49bc-7f65-be73-0970557338b3"
      assert file_download_request["destinationType"] == "STORAGE"
      assert file_download_request["destination"] == nil
      assert file_download_request["progressTracked"] == false
      assert file_download_request["ttlSeconds"] == 100_000
      assert file_download_request["fileName"] == "managed.bin"
      assert file_download_request["uncompressedFileSizeBytes"] == file.size
      assert file_download_request["digest"] == file.base_file.digest
      assert file_download_request["url"] == file.base_file.url
      assert file_download_request["device"]["deviceId"]
    end

    test "returns error when device does not exist", %{tenant: tenant} do
      result =
        create_managed_file_download_request_mutation(
          tenant: tenant,
          device_id: "ZGV2aWNlOjEyMzQ="
        )

      assert %{message: "could not be found"} =
               extract_error!(result, "createManagedFileDownloadRequest")
    end

    test "returns error when file does not exist", %{tenant: tenant} do
      other_tenant = Edgehog.TenantsFixtures.tenant_fixture()
      other_file = file_fixture(tenant: other_tenant)

      expect(StorageMock, :read_presigned_url, 0, fn _ ->
        {:ok, %{get_url: "http://example.test/not-used"}}
      end)

      result =
        create_managed_file_download_request_mutation(
          tenant: tenant,
          file_id: AshGraphql.Resource.encode_relay_id(other_file)
        )

      assert %{message: "could not be found"} =
               extract_error!(result, "createManagedFileDownloadRequest")
    end

    test "chooses correct url and encoding depending on device capabilities", %{tenant: tenant} do
      stub(FileTransferCapabilitiesMock, :get, fn _client, _device_id ->
        {:ok,
         %FileTransferCapabilities{
           encodings: ["gz"],
           unix_permissions: false,
           targets: [:filesystem]
         }}
      end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      file = file_fixture(tenant: tenant, name: "managed.bin")

      result =
        create_managed_file_download_request_mutation(
          tenant: tenant,
          file_id: AshGraphql.Resource.encode_relay_id(file)
        )

      file_download_request =
        extract_result!(result, "createManagedFileDownloadRequest")

      assert file_download_request["url"] == file.gz_file.url
      assert file_download_request["fileName"] == file.name
      assert file_download_request["uncompressedFileSizeBytes"] == file.size
      assert file_download_request["digest"] == file.gz_file.digest
      assert file_download_request["encoding"] == "gz"
    end

    for encoding <- ["gz", "lz4"] do
      test "test encoding #{encoding} for non archive file", %{tenant: tenant} do
        encoding = unquote(encoding)

        stub(FileTransferCapabilitiesMock, :get, fn _client, _device_id ->
          {:ok,
           %FileTransferCapabilities{
             encodings: [encoding],
             unix_permissions: false,
             targets: [:filesystem]
           }}
        end)

        expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

        file = file_fixture(tenant: tenant, name: "managed.bin")

        result =
          create_managed_file_download_request_mutation(
            tenant: tenant,
            file_id: AshGraphql.Resource.encode_relay_id(file)
          )

        expected_file =
          case encoding do
            "gz" -> file.gz_file
            "lz4" -> file.lz4_file
          end

        file_download_request =
          extract_result!(result, "createManagedFileDownloadRequest")

        assert file_download_request["url"] == expected_file.url
        assert file_download_request["fileName"] == file.name
        assert file_download_request["uncompressedFileSizeBytes"] == file.size
        assert file_download_request["digest"] == expected_file.digest
        assert file_download_request["encoding"] == encoding
      end
    end

    for encoding <- ["tar", "tar.gz", "tar.lz4"] do
      test "test encoding #{encoding} for archive file", %{tenant: tenant} do
        encoding = unquote(encoding)

        stub(FileTransferCapabilitiesMock, :get, fn _client, _device_id ->
          {:ok,
           %FileTransferCapabilities{
             encodings: [encoding],
             unix_permissions: false,
             targets: [:filesystem]
           }}
        end)

        expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

        file = file_fixture(tenant: tenant, name: "managed.bin", is_archive: true)

        result =
          create_managed_file_download_request_mutation(
            tenant: tenant,
            file_id: AshGraphql.Resource.encode_relay_id(file)
          )

        expected_file =
          case encoding do
            "tar" -> file.base_file
            "tar.gz" -> file.gz_file
            "tar.lz4" -> file.lz4_file
          end

        file_download_request =
          extract_result!(result, "createManagedFileDownloadRequest")

        assert file_download_request["url"] == expected_file.url
        assert file_download_request["fileName"] == file.name
        assert file_download_request["uncompressedFileSizeBytes"] == file.size
        assert file_download_request["digest"] == expected_file.digest
        assert file_download_request["encoding"] == encoding
      end
    end

    test "fails if we try to upload an archive file without supporting capabilities", %{
      tenant: tenant
    } do
      file = file_fixture(tenant: tenant, name: "managed.bin", is_archive: true)

      result =
        create_managed_file_download_request_mutation(
          tenant: tenant,
          file_id: AshGraphql.Resource.encode_relay_id(file)
        )

      assert %{message: "Device does not support archives"} =
               extract_error!(result, "createManagedFileDownloadRequest")
    end
  end

  defp create_manual_file_download_request_mutation(opts) do
    default_document = """
    mutation CreateManualFileDownloadRequest($input: CreateManualFileDownloadRequestInput!) {
      createManualFileDownloadRequest(input: $input) {
        result {
          id
          device {
            id
            deviceId
          }
          destinationType
          destination
          progressTracked
          ttlSeconds
          url
          fileName
          uncompressedFileSizeBytes
          digest
          encoding
          userId
          groupId
          status
          progressPercentage
          responseCode
          responseMessage
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        [tenant: tenant]
        |> device_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {file, opts} =
      Keyword.pop_lazy(opts, :file, fn ->
        tmp_path =
          Path.join(System.tmp_dir!(), "auto_upload_#{:erlang.unique_integer([:positive])}.bin")

        File.write!(tmp_path, "auto file content")

        %Plug.Upload{
          path: tmp_path,
          filename: "file.bin",
          content_type: "application/octet-stream"
        }
      end)

    {encoding, opts} = Keyword.pop(opts, :encoding, "")

    default_input = %{
      "deviceId" => device_id,
      "file" => file && "file",
      "destinationType" => "STORAGE",
      "destination" => nil,
      "progressTracked" => false,
      "ttlSeconds" => 100_000,
      "fileName" => "filename",
      "uncompressedFileSizeBytes" => 75_555,
      "encoding" => encoding,
      "userId" => 45,
      "groupId" => 55
    }

    {input_overrides, opts} = Keyword.pop(opts, :input, %{})
    input = Map.merge(default_input, input_overrides)

    context = add_upload(%{tenant: tenant}, "file", file)

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: context
    )
  end

  defp create_managed_file_download_request_mutation(opts) do
    default_document = """
    mutation CreateManagedFileDownloadRequest($input: CreateManagedFileDownloadRequestInput!) {
      createManagedFileDownloadRequest(input: $input) {
        result {
          id
          device {
            id
            deviceId
          }
          destinationType
          destination
          progressTracked
          ttlSeconds
          url
          fileName
          uncompressedFileSizeBytes
          digest
          encoding
          userId
          groupId
          status
          progressPercentage
          responseCode
          responseMessage
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        [tenant: tenant]
        |> device_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {file_id, opts} =
      Keyword.pop_lazy(opts, :file_id, fn ->
        [tenant: tenant]
        |> file_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    default_input = %{
      "deviceId" => device_id,
      "fileId" => file_id,
      "destinationType" => "STORAGE",
      "destination" => nil,
      "progressTracked" => false,
      "ttlSeconds" => 100_000,
      "userId" => 45,
      "groupId" => 55
    }

    {input_overrides, opts} = Keyword.pop(opts, :input, %{})
    input = Map.merge(default_input, input_overrides)

    context = %{tenant: tenant}

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: context
    )
  end

  defp extract_error!(result, operation_key) do
    assert is_nil(result[:data][operation_key])
    assert %{errors: [error]} = result
    error
  end

  defp extract_result!(result, operation_key) do
    assert %{
             data: %{
               ^operation_key => %{
                 "result" => file_download_request
               }
             }
           } = result

    refute Map.get(result, :errors)
    file_download_request
  end

  defp build_temp_file!(filename, content) do
    path =
      Path.join(
        System.tmp_dir!(),
        "test_upload_#{System.unique_integer([:positive])}_#{filename}"
      )

    File.write!(path, content)

    ExUnit.Callbacks.on_exit(fn ->
      File.rm(path)
    end)

    path
  end

  defp plug_upload(path, filename) do
    %Plug.Upload{
      path: path,
      filename: filename,
      content_type: "application/octet-stream"
    }
  end
end
