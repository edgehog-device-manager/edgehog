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

defmodule EdgehogWeb.Schema.Mutation.SetLedBehaviorTest do
  use EdgehogWeb.GraphqlCase, async: true

  @moduletag :ported_to_ash

  alias Edgehog.DevicesFixtures

  describe "SetLedBehavior mutation" do
    test "sets BLINK led behavior for the specified device", %{tenant: tenant} do
      {astarte_device_id, graphql_id} = sample_device_id(tenant)

      Edgehog.Astarte.Device.LedBehaviorMock
      |> expect(:post, 1, fn _client, ^astarte_device_id, "Blink60Seconds" -> :ok end)

      result = set_led_behavior_mutation(tenant: tenant, id: graphql_id, behavior: "BLINK")
      assert %{"id" => ^graphql_id} = extract_result!(result)
    end

    test "sets DOUBLE_BLINK led behavior for the specified device", %{tenant: tenant} do
      {astarte_device_id, graphql_id} = sample_device_id(tenant)

      Edgehog.Astarte.Device.LedBehaviorMock
      |> expect(:post, 1, fn _client, ^astarte_device_id, "DoubleBlink60Seconds" -> :ok end)

      result = set_led_behavior_mutation(tenant: tenant, id: graphql_id, behavior: "DOUBLE_BLINK")
      assert %{"id" => ^graphql_id} = extract_result!(result)
    end

    test "sets SLOW_BLINK led behavior for the specified device", %{tenant: tenant} do
      {astarte_device_id, graphql_id} = sample_device_id(tenant)

      Edgehog.Astarte.Device.LedBehaviorMock
      |> expect(:post, 1, fn _client, ^astarte_device_id, "SlowBlink60Seconds" -> :ok end)

      result = set_led_behavior_mutation(tenant: tenant, id: graphql_id, behavior: "SLOW_BLINK")
      assert %{"id" => ^graphql_id} = extract_result!(result)
    end

    test "fails with an invalid behavior", %{tenant: tenant} do
      device = DevicesFixtures.device_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(device)

      assert %{errors: [%{message: msg}]} =
               set_led_behavior_mutation(tenant: tenant, id: id, behavior: "NOT_BLINK")

      assert msg =~ "Expected type \"DeviceLedBehavior!\""
    end

    test "fails with non-existing id", %{tenant: tenant} do
      id = non_existing_device_id(tenant)
      result = set_led_behavior_mutation(tenant: tenant, id: id, behavior: "BLINK")
      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end

    test "does not send data to Astarte with invalid data", %{tenant: tenant} do
      device = DevicesFixtures.device_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(device)

      Edgehog.Astarte.Device.LedBehaviorMock
      |> expect(:post, 0, fn _client, _device_id, _behavior -> raise "Error!" end)

      assert %{errors: [%{message: _msg}]} =
               set_led_behavior_mutation(tenant: tenant, id: id, behavior: "FOO")
    end
  end

  defp set_led_behavior_mutation(opts) do
    default_document = """
    mutation SetDeviceLedBehavior($id: ID!, $input: SetDeviceLedBehaviorInput!) {
      setDeviceLedBehavior(id: $id, input: $input) {
        result {
          id
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)
    {behavior, opts} = Keyword.pop!(opts, :behavior)

    input = %{"behavior" => behavior}

    variables = %{"id" => id, "input" => input}
    document = Keyword.get(opts, :document, default_document)
    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{
             data: %{
               "setDeviceLedBehavior" => %{
                 "result" => device
               }
             }
           } = result

    assert device != nil

    device
  end

  defp sample_device_id(tenant) do
    device = DevicesFixtures.device_fixture(tenant: tenant)
    graphql_id = AshGraphql.Resource.encode_relay_id(device)
    astarte_device_id = device.device_id

    {astarte_device_id, graphql_id}
  end

  defp non_existing_device_id(tenant) do
    fixture = DevicesFixtures.device_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end
end
