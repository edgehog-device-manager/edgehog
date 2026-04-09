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

defmodule EdgehogWeb.Schema.Mutation.CreateFileUploadRequestTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures

  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.FileUploadRequest.RequestData
  alias Edgehog.Astarte.Device.FileUploadRequestMock
  alias Edgehog.StorageMock

  describe "createFileUploadRequest mutation" do
    test "creates file upload request with all fields", %{tenant: tenant} do
      expect(StorageMock, :create_presigned_urls, fn path ->
        assert String.contains?(path, "uploads/tenants/#{tenant.tenant_id}/file_upload_requests/")

        {:ok,
         %{
           put_url: "http://example.test/upload",
           get_url: "http://example.test/download"
         }}
      end)

      expect(FileUploadRequestMock, :request_upload, fn _client, device_id, request_data ->
        assert is_binary(device_id)

        assert %RequestData{
                 id: request_id,
                 url: "http://example.test/upload",
                 httpHeaderKeys: ["x-ms-blob-type"],
                 httpHeaderValues: ["BlockBlob"],
                 encoding: "gzip",
                 progress: true,
                 source: "/var/log/messages",
                 sourceType: :filesystem
               } = request_data

        assert is_binary(request_id)
        :ok
      end)

      result = create_file_upload_request_mutation(tenant: tenant)

      file_upload_request = extract_result!(result, "createFileUploadRequest")

      assert is_binary(file_upload_request["id"])
      assert file_upload_request["url"] == "http://example.test/upload"
      assert file_upload_request["source"] == "/var/log/messages"
      assert file_upload_request["sourceType"] == "FILESYSTEM"
      assert file_upload_request["encoding"] == "gzip"
      assert file_upload_request["progressTracked"] == true
      assert file_upload_request["status"] == "PENDING"
      assert file_upload_request["progressPercentage"] == nil
      assert file_upload_request["responseCode"] == nil
      assert file_upload_request["responseMessage"] == nil
      assert normalize_json_map(file_upload_request["httpHeaders"]) == %{"X-Test" => "1"}

      assert file_upload_request["device"]["deviceId"]
    end

    test "returns error when device does not exist", %{tenant: tenant} do
      result =
        create_file_upload_request_mutation(
          tenant: tenant,
          device_id: "ZGV2aWNlOjEyMzQ="
        )

      assert %{code: "not_found"} = extract_error!(result, "createFileUploadRequest")
    end

    test "fails if Astarte API returns error", %{tenant: tenant} do
      expect(StorageMock, :create_presigned_urls, fn _path ->
        {:ok,
         %{
           put_url: "http://example.test/upload",
           get_url: "http://example.test/download"
         }}
      end)

      expect(FileUploadRequestMock, :request_upload, fn _, _, _ ->
        {:error, %APIError{status: 500, response: "Internal Server Error"}}
      end)

      result = create_file_upload_request_mutation(tenant: tenant)

      assert %{code: "astarte_api_error", short_message: "Astarte API Error (status 500)"} =
               extract_error!(result, "createFileUploadRequest")
    end
  end

  defp create_file_upload_request_mutation(opts) do
    default_document = """
    mutation CreateFileUploadRequest($input: CreateFileUploadRequestInput!) {
      createFileUploadRequest(input: $input) {
        result {
          id
          device {
            id
            deviceId
          }
          url
          source
          sourceType
          encoding
          progressTracked
          status
          progressPercentage
          responseCode
          responseMessage
          httpHeaders
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
      "source" => "/var/log/messages",
      "sourceType" => "FILESYSTEM",
      "encoding" => "gzip",
      "progressTracked" => true,
      "httpHeaders" => Jason.encode!(%{"X-Test" => "1"})
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
                 "result" => file_upload_request
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert file_upload_request

    file_upload_request
  end

  defp normalize_json_map(value) when is_map(value), do: value
  defp normalize_json_map(value) when is_binary(value), do: Jason.decode!(value)
end
