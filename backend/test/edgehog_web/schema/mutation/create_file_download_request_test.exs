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

  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.FileDownloadRequestMock

  describe "createFileDownloadRequest mutation" do
    test "creates file download request with all fields", %{tenant: tenant} do
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ -> :ok end)

      result =
        create_file_download_request_mutation(tenant: tenant)

      file_download_request = extract_result!(result)

      assert file_download_request["id"] != "019c997a-49bc-7f65-be73-0970557338b3"
      assert file_download_request["url"] == "http://example/filename"
      assert file_download_request["destination"] == "STORAGE"
      assert file_download_request["progress"] == false
      assert file_download_request["ttlSeconds"] == 100_000
      assert file_download_request["fileName"] == "filename"
      assert file_download_request["uncompressedFileSizeBytes"] == 75_555
      assert file_download_request["digest"] == "sha256:jfkdgjkj"
      assert file_download_request["compression"] == nil
      assert file_download_request["userId"] == 45
      assert file_download_request["groupId"] == 55

      assert file_download_request["device"]["deviceId"]
    end

    test "returns error when device does not exist", %{tenant: tenant} do
      result =
        create_file_download_request_mutation(
          tenant: tenant,
          device_id: "ZGV2aWNlOjEyMzQ="
        )

      assert %{message: "could not be found"} = extract_error!(result)
    end

    test "fails if Astarte API returns error", %{
      tenant: tenant
    } do
      expect(FileDownloadRequestMock, :request_download, fn _, _, _ ->
        {:error, %APIError{status: 500, response: "Internal Server Error"}}
      end)

      result =
        create_file_download_request_mutation(tenant: tenant)

      assert %{code: "astarte_api_error", short_message: "Astarte API Error (status 500)"} =
               extract_error!(result)
    end
  end

  # describe "PresignedUrl mutation" do
  #   test "returns presigned URLs containing the correct file path", %{tenant: tenant} do
  #     tenant_id = tenant.tenant_id
  #     file_download_request_id = "36075cab-9c99-4659-ab47-f5cb993e18e3"
  #     filename = "My File 1"

  #     result =
  #       presigned_url_mutation(
  #         tenant: tenant,
  #         input: %{
  #           "filename" => filename,
  #           "file_download_request_id" => file_download_request_id
  #         }
  #       )

  #     assert %{data: %{"createFileDownloadRequestPresignedUrl" => raw_json}} = result
  #     assert {:ok, decoded_map} = Jason.decode(raw_json)

  #     assert Map.has_key?(decoded_map, "get_url")
  #     assert Map.has_key?(decoded_map, "put_url")

  #     get_url = decoded_map["get_url"]
  #     put_url = decoded_map["put_url"]

  #     encoded_filename = URI.encode(filename)

  #     expected_path =
  #       "uploads/tenants/#{tenant_id}/ephemeral_file_download_requests/#{file_download_request_id}/files/#{encoded_filename}"

  #     assert get_url =~ expected_path
  #     assert put_url =~ expected_path
  #   end

  #   test "returns get presigned url only", %{tenant: tenant} do
  #     tenant_id = tenant.tenant_id
  #     file_download_request_id = "36075cab-9c99-4659-ab47-f5cb993e18e3"
  #     filename = "My File 1"

  #     result =
  #       presigned_url_mutation(
  #         tenant: tenant,
  #         document: """
  #         mutation ReadFileDownloadRequestPresignedUrl($input: ReadFileDownloadRequestPresignedUrlInput!) {
  #           readFileDownloadRequestPresignedUrl(input: $input)
  #         }
  #         """,
  #         input: %{
  #           "filename" => filename,
  #           "file_download_request_id" => file_download_request_id
  #         }
  #       )

  #     assert %{data: %{"readFileDownloadRequestPresignedUrl" => raw_json}} = result
  #     assert {:ok, decoded_map} = Jason.decode(raw_json)

  #     assert Map.has_key?(decoded_map, "get_url")

  #     get_url = decoded_map["get_url"]

  #     encoded_filename = URI.encode(filename)

  #     expected_path =
  #       "uploads/tenants/#{tenant_id}/ephemeral_file_download_requests/#{file_download_request_id}/files/#{encoded_filename}"

  #     assert get_url =~ expected_path
  #   end

  #   defp presigned_url_mutation(opts) do
  #     default_document = """
  #     mutation CreateFileDownloadRequestPresignedUrl($input: CreateFileDownloadRequestPresignedUrlInput!) {
  #       createFileDownloadRequestPresignedUrl(input: $input)
  #     }
  #     """

  #     {tenant, opts} = Keyword.pop!(opts, :tenant)

  #     default_input = %{
  #       "filename" => "My File",
  #       "file_download_request_id" => "36075cab-9c99-4659-ab47-f5cb993e18e3"
  #     }

  #     {input_overrides, opts} = Keyword.pop(opts, :input, %{})
  #     input = Map.merge(default_input, input_overrides)

  #     context = %{tenant: tenant}
  #     variables = %{"input" => input}
  #     document = Keyword.get(opts, :document, default_document)

  #     Absinthe.run!(document, EdgehogWeb.Schema,
  #       variables: variables,
  #       context: context
  #     )
  #   end
  # end

  defp create_file_download_request_mutation(opts) do
    default_document = """
    mutation CreateFileDownloadRequest($input: CreateFileDownloadRequestInput!) {
      createFileDownloadRequest(input: $input) {
        result {
          id
          device {
            id
            deviceId
          }
          destination
          progress
          ttlSeconds
          url
          fileName
          uncompressedFileSizeBytes
          digest
          compression
          userId
          groupId
          status
          statusProgress
          statusCode
          message
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
      "destination" => "STORAGE",
      "progress" => false,
      "ttlSeconds" => 100_000,
      "url" => "http://example/filename",
      "fileName" => "filename",
      "uncompressedFileSizeBytes" => 75_555,
      "digest" => "sha256:jfkdgjkj",
      "compression" => "",
      "userId" => 45,
      "groupId" => 55,
      "fileDownloadRequestId" => "019c997a-49bc-7f65-be73-0970557338b3"
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

  defp extract_error!(result) do
    assert is_nil(result[:data]["createFileDownloadRequest"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createFileDownloadRequest" => %{
                 "result" => file_download_request
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert file_download_request

    file_download_request
  end
end
