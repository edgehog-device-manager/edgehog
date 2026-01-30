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

defmodule EdgehogWeb.Schema.Mutation.CreateManualOTAOperationExistingBaseImageTest do
  use EdgehogWeb.GraphqlCase

  import Edgehog.DevicesFixtures

  alias Edgehog.Astarte.Device.OTARequestV1Mock
  alias Edgehog.OSManagement.OTAOperation

  describe "createManualOtaOperationExistingBaseImage mutation" do
    test "creates OTA operation with valid data", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      device_id = AshGraphql.Resource.encode_relay_id(device)
      astarte_device_id = device.device_id

      base_image_url = "https://example.com/image.bin"

      expect(OTARequestV1Mock, :update, fn _client, ^astarte_device_id, _uuid, ^base_image_url ->
        :ok
      end)

      result =
        create_ota_operation_mutation(
          tenant: tenant,
          device_id: device_id,
          base_image_url: base_image_url
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

    test "publishes on PubSub aftering creating the OTA operation", %{tenant: tenant} do
      assert :ok = Phoenix.PubSub.subscribe(Edgehog.PubSub, "ota_operations:*")

      expect(OTARequestV1Mock, :update, fn _client, _astarte_device_id, _uuid, "https://example.com/image.bin" ->
        :ok
      end)

      ota_operation = [tenant: tenant] |> create_ota_operation_mutation() |> extract_result!()

      assert_receive %Phoenix.Socket.Broadcast{
        event: "manual",
        payload: %Ash.Notifier.Notification{data: %OTAOperation{} = ota_operation_event}
      }

      assert AshGraphql.Resource.encode_relay_id(ota_operation_event) == ota_operation["id"]
    end
  end

  defp create_ota_operation_mutation(opts) do
    default_document = """
    mutation CreateManualOtaOperationExistingBaseImage($input: CreateManualOtaOperationExistingBaseImageInput!) {
      createManualOtaOperationExistingBaseImage(input: $input) {
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
        [tenant: tenant]
        |> device_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {base_image_url, opts} =
      Keyword.pop(opts, :base_image_file, "https://example.com/image.bin")

    input = %{
      "deviceId" => device_id,
      "base_image_url" => base_image_url
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant}
    )
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["createManualOtaOperationExistingBaseImage"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createManualOtaOperationExistingBaseImage" => %{
                 "result" => ota_operation
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert ota_operation

    ota_operation
  end

  defp non_existing_device_id(tenant) do
    fixture = device_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end
end
