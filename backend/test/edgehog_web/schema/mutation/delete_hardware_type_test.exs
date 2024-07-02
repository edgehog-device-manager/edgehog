#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.DeleteHardwareTypeTest do
  use EdgehogWeb.GraphqlCase, async: true

  alias Edgehog.Devices
  alias Edgehog.Devices.HardwareType

  import Edgehog.DevicesFixtures

  describe "deleteHardwareType field" do
    test "deletes hardware type", %{tenant: tenant} do
      fixture = hardware_type_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(fixture)

      result = delete_hardware_type_mutation(tenant: tenant, id: id)

      hardware_type = extract_result!(result)

      assert hardware_type["id"] == id
    end

    test "fails with non-existing id", %{tenant: tenant} do
      id = non_existing_hardware_type_id(tenant)

      result = delete_hardware_type_mutation(tenant: tenant, id: id)

      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end
  end

  defp non_existing_hardware_type_id(tenant) do
    fixture = hardware_type_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end

  defp delete_hardware_type_mutation(opts) do
    default_document = """
    mutation DeleteHardwareType($id: ID!) {
      deleteHardwareType(id: $id) {
        result {
          id
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables = %{"id" => id}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_error!(result) do
    assert %{
             data: %{
               "deleteHardwareType" => nil
             },
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{
             data: %{
               "deleteHardwareType" => %{
                 "result" => hardware_type
               }
             }
           } = result

    assert hardware_type != nil

    hardware_type
  end
end
