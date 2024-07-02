#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.CreateManualOTAOperationTest do
  use EdgehogWeb.GraphqlCase

  alias Edgehog.PubSub
  alias Edgehog.OSManagement.OTAOperation

  import Edgehog.DevicesFixtures

  describe "createManualOtaOperation mutation" do
    test "creates OTA operation with valid data", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      device_id = AshGraphql.Resource.encode_relay_id(device)
      astarte_device_id = device.device_id

      base_image_url = "https://example.com/image.bin"

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:upload, fn _, _, _ -> {:ok, base_image_url} end)

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _client, ^astarte_device_id, _uuid, ^base_image_url ->
        :ok
      end)

      result =
        create_ota_operation_mutation(
          tenant: tenant,
          device_id: device_id,
          base_image_file: %Plug.Upload{path: "test/fixtures/image.bin", filename: "image.bin"}
        )

      ota_operation = extract_result!(result)

      assert %{
               "baseImageUrl" => ^base_image_url,
               "status" => "PENDING",
               "createdAt" => _created_at,
               "updatedAt" => _updated_at,
               "device" => %{
                 "deviceId" => ^astarte_device_id
               }
             } = ota_operation
    end

    test "fails with non-existing device id", %{tenant: tenant} do
      device_id = non_existing_device_id(tenant)
      result = create_ota_operation_mutation(tenant: tenant, device_id: device_id)

      assert %{message: "could not be found"} = extract_error!(result)
    end

    test "fails if the base image upload fails", %{tenant: tenant} do
      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:upload, fn _, _, _ -> {:error, :no_space_left_in_the_internet} end)

      result = create_ota_operation_mutation(tenant: tenant)

      assert %{fields: [:base_image_file], message: "failed to upload"} = extract_error!(result)
    end

    test "cleans up the ephemeral image if an API error is returned", %{tenant: tenant} do
      base_image_url = "https://example.com/image.bin"

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:upload, fn _, _, _ -> {:ok, base_image_url} end)
      |> expect(:delete, fn _, _, _ -> :ok end)

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _, _, _, _ ->
        {:error, api_error(status: 418, message: "I'm a teapot")}
      end)

      result = create_ota_operation_mutation(tenant: tenant)

      assert %{code: "astarte_api_error", message: message} = extract_error!(result)
      assert message =~ "418"
      assert message =~ "I'm a teapot"
    end

    test "publishes on PubSub aftering creating the OTA operation", %{tenant: tenant} do
      assert :ok = PubSub.subscribe_to_events_for(:ota_operations)

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:upload, fn _, _, _ -> {:ok, "base_image_url"} end)

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _client, _astarte_device_id, _uuid, "base_image_url" ->
        :ok
      end)

      ota_operation = create_ota_operation_mutation(tenant: tenant) |> extract_result!()

      assert_receive {:ota_operation_created, %OTAOperation{} = ota_operation_event}

      assert AshGraphql.Resource.encode_relay_id(ota_operation_event) == ota_operation["id"]
    end
  end

  defp create_ota_operation_mutation(opts) do
    default_document = """
    mutation CreateManualOtaOperation($input: CreateManualOtaOperationInput!) {
      createManualOtaOperation(input: $input) {
        result {
          id
          baseImageUrl
          status
          createdAt
          updatedAt
          device {
            deviceId
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        device_fixture(tenant: tenant)
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {base_image_file, opts} =
      Keyword.pop_lazy(opts, :base_image_file, fn ->
        %Plug.Upload{path: "/tmp/ota.bin", filename: "ota.bin"}
      end)

    input = %{
      "deviceId" => device_id,
      "base_image_file" => base_image_file && "base_image_file"
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    context =
      %{tenant: tenant}
      |> add_upload("base_image_file", base_image_file)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: context
    )
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["createManualOtaOperation"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createManualOtaOperation" => %{
                 "result" => ota_operation
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert ota_operation != nil

    ota_operation
  end

  defp non_existing_device_id(tenant) do
    fixture = device_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

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
end
