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
  alias Edgehog.Astarte.Device.DeviceStatusMock
  alias Edgehog.Astarte.Device.FileDownloadRequestMock
  alias Edgehog.Astarte.Device.FileTransferCapabilities
  alias Edgehog.Astarte.Device.FileTransferCapabilitiesMock
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
    test "creates file download request with all fields", %{tenant: tenant} do
      # This sets the capabilities to [] to avoid the check on the presence of the FileTransfer interface
      stub(DeviceStatusMock, :get, fn _client, _device_id -> {:error, :not_found} end)
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      result =
        create_manual_file_download_request_mutation(tenant: tenant)

      file_download_request = extract_result!(result, "createManualFileDownloadRequest")

      assert file_download_request["id"] != "019c997a-49bc-7f65-be73-0970557338b3"
      assert file_download_request["url"] == "http://example/filename"
      assert file_download_request["destinationType"] == "STORAGE"
      assert file_download_request["destination"] == nil
      assert file_download_request["progressTracked"] == false
      assert file_download_request["ttlSeconds"] == 100_000
      assert file_download_request["fileName"] == "filename"
      assert file_download_request["uncompressedFileSizeBytes"] == 75_555
      assert file_download_request["digest"] == "sha256:jfkdgjkj"
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

    test "fails if Astarte API returns error", %{
      tenant: tenant
    } do
      stub(DeviceStatusMock, :get, fn _client, _device_id -> {:error, :not_found} end)

      expect(FileDownloadRequestMock, :request_download, fn _, _, _ ->
        {:error, %APIError{status: 500, response: "Internal Server Error"}}
      end)

      result =
        create_manual_file_download_request_mutation(tenant: tenant)

      assert %{code: "astarte_api_error", short_message: "Astarte API Error (status 500)"} =
               extract_error!(result, "createManualFileDownloadRequest")
    end
  end

  describe "createManagedFileDownloadRequest mutation" do
    test "creates managed file download request from file", %{tenant: tenant} do
      stub(DeviceStatusMock, :get, fn _client, _device_id -> {:error, :not_found} end)
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      file = file_fixture(tenant: tenant, name: "managed.bin", size: 1234, digest: "sha256:abcd")

      expect(StorageMock, :read_presigned_url, fn path ->
        assert String.contains?(path, "uploads/tenants/")
        assert String.contains?(path, "/repositories/#{file.repository_id}/")
        assert String.ends_with?(path, "/managed.bin")

        {:ok, %{get_url: "http://example.test/#{path}"}}
      end)

      result =
        create_managed_file_download_request_mutation(
          tenant: tenant,
          file_id: AshGraphql.Resource.encode_relay_id(file)
        )

      file_download_request = extract_result!(result, "createManagedFileDownloadRequest")

      assert file_download_request["id"] != "019c997a-49bc-7f65-be73-0970557338b3"
      assert file_download_request["destinationType"] == "STORAGE"
      assert file_download_request["destination"] == nil
      assert file_download_request["progressTracked"] == false
      assert file_download_request["ttlSeconds"] == 100_000
      assert file_download_request["fileName"] == "managed.bin"
      assert file_download_request["uncompressedFileSizeBytes"] == 1234
      assert file_download_request["digest"] == "sha256:abcd"
      assert String.contains?(file_download_request["url"], "uploads/tenants/")

      assert String.contains?(
               file_download_request["url"],
               "/repositories/#{file.repository_id}/"
             )

      assert String.contains?(file_download_request["url"], "/managed.bin")

      assert file_download_request["device"]["deviceId"]
    end

    test "returns error when file does not exist", %{tenant: tenant} do
      other_tenant = Edgehog.TenantsFixtures.tenant_fixture()
      other_file = file_fixture(tenant: other_tenant)

      expect(StorageMock, :read_presigned_url, 0, fn _path ->
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

    default_input = %{
      "deviceId" => device_id,
      "destinationType" => "STORAGE",
      "destination" => nil,
      "progressTracked" => false,
      "ttlSeconds" => 100_000,
      "url" => "http://example/filename",
      "fileName" => "filename",
      "uncompressedFileSizeBytes" => 75_555,
      "digest" => "sha256:jfkdgjkj",
      "encoding" => "",
      "userId" => 45,
      "groupId" => 55,
      "fileDownloadRequestId" => Ash.UUIDv7.generate()
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
      "encoding" => "",
      "userId" => 45,
      "groupId" => 55,
      "fileDownloadRequestId" => Ash.UUIDv7.generate()
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

    assert file_download_request

    file_download_request
  end
end
