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

defmodule EdgehogWeb.Schema.Mutation.CreateFileDeleteRequestTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures

  # alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.FileDeleteRequestMock

  describe "createFileDeleteRequest mutation" do
    test "creates File Delete Request with all fields", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      device_id = AshGraphql.Resource.encode_relay_id(device)

      file_download_request =
        manual_file_download_request_fixture(tenant: tenant, device_id: device.id)

      file_download_request_id = AshGraphql.Resource.encode_relay_id(file_download_request)

      expect(FileDeleteRequestMock, :request_deletion, fn _, _, _ -> :ok end)

      result =
        create_file_delete_request_mutation(
          tenant: tenant,
          device_id: device_id,
          file_download_request_id: file_download_request_id
        )

      file_delete_request = extract_result!(result)

      assert %{
               "fileDownloadRequest" => %{"id" => ^file_download_request_id},
               "status" => "PENDING",
               "force" => false,
               "device" => %{
                 "id" => ^device_id
               }
             } = file_delete_request
    end

    test "fails with non-existing device id", %{tenant: tenant} do
      device_id = non_existing_device_id(tenant)

      result =
        create_file_delete_request_mutation(
          tenant: tenant,
          device_id: device_id,
          sources: [:file]
        )

      assert %{message: "does not belong to device"} = extract_error!(result)
    end

    test "fails with non-existing file download request id", %{tenant: tenant} do
      file_download_request_id = non_existing_file_download_request_id(tenant)

      result =
        create_file_delete_request_mutation(
          tenant: tenant,
          file_download_request_id: file_download_request_id,
          sources: [:file]
        )

      assert %{message: "could not be found"} = extract_error!(result)
    end

    test "fails when file download request belongs to a different device", %{tenant: tenant} do
      device_a = device_fixture(tenant: tenant)
      device_b = device_fixture(tenant: tenant)

      file_download_request =
        manual_file_download_request_fixture(tenant: tenant, device_id: device_a.id)

      result =
        create_file_delete_request_mutation(
          tenant: tenant,
          device_id: AshGraphql.Resource.encode_relay_id(device_b),
          file_download_request_id: AshGraphql.Resource.encode_relay_id(file_download_request)
        )

      assert %{message: "does not belong to device"} = extract_error!(result)
    end

    test "fails when file download request is not storage", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)

      file_download_request =
        manual_file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          destination_type: "filesystem"
        )

      result =
        create_file_delete_request_mutation(
          tenant: tenant,
          device_id: AshGraphql.Resource.encode_relay_id(device),
          file_download_request_id: AshGraphql.Resource.encode_relay_id(file_download_request)
        )

      assert %{message: "must be storage"} = extract_error!(result)
    end
  end

  test "fails if an API error is returned", %{tenant: tenant} do
    expect(FileDeleteRequestMock, :request_deletion, fn _, _, _ ->
      {:error, api_error(status: 418, message: "I'm a teapot")}
    end)

    device = device_fixture(tenant: tenant)

    file_download_request =
      manual_file_download_request_fixture(tenant: tenant, device_id: device.id)

    result =
      create_file_delete_request_mutation(
        tenant: tenant,
        device_id: AshGraphql.Resource.encode_relay_id(device),
        file_download_request_id: AshGraphql.Resource.encode_relay_id(file_download_request)
      )

    assert %{code: "astarte_api_error", message: message} = extract_error!(result)
    assert message =~ "418"
    assert message =~ "I'm a teapot"
  end

  defp create_file_delete_request_mutation(opts) do
    default_document = """
    mutation CreateFileDeleteRequest($input: CreateFileDeleteRequestInput!) {
      createFileDeleteRequest(input: $input) {
        result {
          id
          device {
            id
            deviceId
          }
          force
          status
          responseCode
          responseMessages
          fileDownloadRequest {
            id
          }
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

    {file_download_request_id, opts} =
      Keyword.pop_lazy(opts, :file_download_request_id, fn ->
        [tenant: tenant]
        |> manual_file_download_request_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {force, opts} = Keyword.pop_lazy(opts, :force, fn -> false end)

    default_input = %{
      "deviceId" => device_id,
      "fileDownloadRequestId" => file_download_request_id,
      "force" => force
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

  defp non_existing_device_id(tenant) do
    fixture = device_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end

  defp non_existing_file_download_request_id(tenant) do
    fixture = manual_file_download_request_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture, action: :destroy_fixture)

    id
  end

  defp api_error(opts) do
    status = Keyword.get(opts, :status, 500)
    message = Keyword.get(opts, :message, "Generic error")

    %Astarte.Client.APIError{
      status: status,
      response: %{"errors" => %{"detail" => message}}
    }
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["createFileDeleteRequest"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createFileDeleteRequest" => %{
                 "result" => file_delete_request
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert file_delete_request

    file_delete_request
  end
end
