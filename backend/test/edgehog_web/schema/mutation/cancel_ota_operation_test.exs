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

defmodule EdgehogWeb.Schema.Mutation.CancelOtaOperationTest do
  use EdgehogWeb.GraphqlCase

  import Edgehog.DevicesFixtures
  import Edgehog.OSManagementFixtures

  alias Edgehog.Astarte.Device.OTARequestV1Mock

  describe "cancelOtaOperation mutation" do
    test "cancels OTA operation with valid data", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      astarte_device_id = device.device_id

      ota_operation =
        manual_ota_operation_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :pending
        )

      ota_operation_id = AshGraphql.Resource.encode_relay_id(ota_operation)

      expect(OTARequestV1Mock, :cancel, fn _client, ^astarte_device_id, _uuid ->
        :ok
      end)

      result =
        cancel_ota_operation_mutation(
          tenant: tenant,
          ota_operation_id: ota_operation_id
        )

      response = extract_result!(result)

      assert %{"id" => ^ota_operation_id, "status" => _status} = response
    end

    test "fails with non-existing OTA operation id", %{tenant: tenant} do
      ota_operation_id = non_existing_ota_operation_id(tenant)

      result =
        cancel_ota_operation_mutation(
          tenant: tenant,
          ota_operation_id: ota_operation_id
        )

      assert %{message: "could not be found"} = extract_error!(result)
    end

    test "fails if the Astarte API returns an error", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)

      ota_operation =
        manual_ota_operation_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :pending
        )

      ota_operation_id = AshGraphql.Resource.encode_relay_id(ota_operation)

      expect(OTARequestV1Mock, :cancel, fn _client, _device_id, _uuid ->
        {:error, api_error(status: 503, message: "Service unavailable")}
      end)

      result =
        cancel_ota_operation_mutation(
          tenant: tenant,
          ota_operation_id: ota_operation_id
        )

      assert %{code: "astarte_api_error", message: message} = extract_error!(result)
      assert message =~ "503"
      assert message =~ "Service unavailable"
    end

    test "cancels OTA operation for managed OTA operation", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      astarte_device_id = device.device_id

      ota_operation =
        managed_ota_operation_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :pending
        )

      ota_operation_id = AshGraphql.Resource.encode_relay_id(ota_operation)

      expect(OTARequestV1Mock, :cancel, fn _client, ^astarte_device_id, _uuid ->
        :ok
      end)

      result =
        cancel_ota_operation_mutation(
          tenant: tenant,
          ota_operation_id: ota_operation_id
        )

      response = extract_result!(result)

      assert %{"id" => ^ota_operation_id} = response
    end

    test "cancels OTA operation in downloading state", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      astarte_device_id = device.device_id

      ota_operation =
        manual_ota_operation_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :downloading
        )

      ota_operation_id = AshGraphql.Resource.encode_relay_id(ota_operation)

      expect(OTARequestV1Mock, :cancel, fn _client, ^astarte_device_id, _uuid ->
        :ok
      end)

      result =
        cancel_ota_operation_mutation(
          tenant: tenant,
          ota_operation_id: ota_operation_id
        )

      response = extract_result!(result)

      assert %{"id" => ^ota_operation_id} = response
    end

    test "cancels OTA operation in deploying state", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      astarte_device_id = device.device_id

      ota_operation =
        manual_ota_operation_fixture(
          tenant: tenant,
          device_id: device.id,
          status: :deploying
        )

      ota_operation_id = AshGraphql.Resource.encode_relay_id(ota_operation)

      expect(OTARequestV1Mock, :cancel, fn _client, ^astarte_device_id, _uuid ->
        :ok
      end)

      result =
        cancel_ota_operation_mutation(
          tenant: tenant,
          ota_operation_id: ota_operation_id
        )

      response = extract_result!(result)

      assert %{"id" => ^ota_operation_id} = response
    end
  end

  defp cancel_ota_operation_mutation(opts) do
    default_document = """
    mutation CancelOtaOperation($id: ID!) {
      cancelOtaOperation(id: $id) {
        result {
          id
          status
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {ota_operation_id, opts} =
      Keyword.pop_lazy(opts, :ota_operation_id, fn ->
        [tenant: tenant]
        |> manual_ota_operation_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    variables = %{
      "id" => ota_operation_id
    }

    document = Keyword.get(opts, :document, default_document)

    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: context
    )
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["cancelOtaOperation"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "cancelOtaOperation" => %{
                 "result" => ota_operation
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert ota_operation

    ota_operation
  end

  defp non_existing_ota_operation_id(tenant) do
    fixture = manual_ota_operation_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    # Expect the ephemeral image deletion since we're destroying a manual OTA operation
    expect(Edgehog.OSManagement.EphemeralImageMock, :delete, fn _tenant_id, _ota_operation_id, _url ->
      :ok
    end)

    :ok = Ash.destroy!(fixture, action: :destroy)

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
