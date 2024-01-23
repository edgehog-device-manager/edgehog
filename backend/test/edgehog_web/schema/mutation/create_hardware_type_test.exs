#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.CreateHardwareTypeTest do
  use EdgehogWeb.GraphqlCase, async: true

  alias Edgehog.Devices
  alias Edgehog.Devices.HardwareType

  import Edgehog.DevicesFixtures

  @moduletag :ported_to_ash

  describe "createHardwareType mutation" do
    test "creates hardware type with valid data", %{tenant: tenant} do
      result =
        create_hardware_type_mutation(
          tenant: tenant,
          name: "Foobar",
          handle: "foobar",
          part_numbers: ["123", "456"]
        )

      hardware_type = extract_result!(result)

      assert %{
               "id" => _,
               "name" => "Foobar",
               "handle" => "foobar",
               "partNumbers" => part_numbers
             } = hardware_type

      assert length(part_numbers) == 2
      assert %{"partNumber" => "123"} in part_numbers
      assert %{"partNumber" => "456"} in part_numbers
    end

    test "returns error for invalid handle", %{tenant: tenant} do
      result =
        create_hardware_type_mutation(
          tenant: tenant,
          handle: "123Invalid$"
        )

      assert %{"fields" => ["handle"], "message" => "should only contain" <> _} =
               extract_error!(result)
    end

    test "returns error for empty part_numbers", %{tenant: tenant} do
      result =
        create_hardware_type_mutation(
          tenant: tenant,
          part_numbers: []
        )

      assert %{"fields" => ["part_numbers"], "message" => "must have 1 or more items"} =
               extract_error!(result)
    end

    test "returns error for duplicate name", %{tenant: tenant} do
      fixture = hardware_type_fixture(tenant: tenant)

      result =
        create_hardware_type_mutation(
          tenant: tenant,
          name: fixture.name
        )

      assert %{"fields" => ["name"], "message" => "has already been taken"} =
               extract_error!(result)
    end

    test "returns error for duplicate handle", %{tenant: tenant} do
      fixture = hardware_type_fixture(tenant: tenant)

      result =
        create_hardware_type_mutation(
          tenant: tenant,
          handle: fixture.handle
        )

      assert %{"fields" => ["handle"], "message" => "has already been taken"} =
               extract_error!(result)
    end

    test "reassociates an existing HardwareTypePartNumber", %{tenant: tenant} do
      # TODO: see issue #228, this documents the current behaviour

      fixture = hardware_type_fixture(tenant: tenant, part_numbers: ["foo", "bar"])

      result =
        create_hardware_type_mutation(
          tenant: tenant,
          part_numbers: ["foo"]
        )

      _ = extract_result!(result)

      assert %HardwareType{part_number_strings: ["bar"]} =
               HardwareType
               |> Devices.get!(fixture.id, tenant: tenant)
               |> Devices.load!(:part_number_strings)
    end
  end

  defp create_hardware_type_mutation(opts) do
    default_document = """
    mutation CreateHardwareType($input: CreateHardwareTypeInput!) {
      createHardwareType(input: $input) {
        result {
          id
          name
          handle
          partNumbers {
            partNumber
          }
        }
        errors {
          code
          fields
          message
          shortMessage
          vars
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    input = %{
      "handle" => opts[:handle] || unique_hardware_type_handle(),
      "name" => opts[:name] || unique_hardware_type_name(),
      "partNumbers" => opts[:part_numbers] || [unique_hardware_type_part_number()]
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_error!(result) do
    assert %{
             data: %{
               "createHardwareType" => %{
                 "result" => nil,
                 "errors" => [error]
               }
             }
           } = result

    error
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{
             data: %{
               "createHardwareType" => %{
                 "result" => hardware_type,
                 "errors" => []
               }
             }
           } = result

    assert hardware_type != nil

    hardware_type
  end
end
