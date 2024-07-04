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

defmodule EdgehogWeb.Schema.Mutation.UpdateDeviceTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures

  alias Edgehog.Devices
  alias Edgehog.Devices.SystemModel

  describe "updateDevice mutation" do
    setup %{tenant: tenant} do
      device = device_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(device)

      %{device: device, id: id}
    end

    test "successfully updates with valid data", %{tenant: tenant, device: device, id: id} do
      result = update_device_mutation(tenant: tenant, id: id, name: "Updated Name")
      assert %{"name" => "Updated Name"} = extract_result!(result)
    end

    test "fails with non-existing id", %{tenant: tenant} do
      id = non_existing_device_id(tenant)
      result = update_device_mutation(tenant: tenant, id: id, name: "Updated Name")
      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end
  end

  defp update_device_mutation(opts) do
    default_document = """
    mutation UpdateDevice($id: ID!, $input: UpdateDeviceInput!) {
      updateDevice(id: $id, input: $input) {
        result {
          name
          deviceId
          online
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    input =
      %{"name" => opts[:name]}
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Map.new()

    variables = %{"id" => id, "input" => input}
    document = Keyword.get(opts, :document, default_document)
    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"updateDevice" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{
             data: %{
               "updateDevice" => %{
                 "result" => device
               }
             }
           } = result

    assert device != nil

    device
  end

  defp non_existing_device_id(tenant) do
    fixture = device_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end
end
