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

defmodule EdgehogWeb.Schema.Mutation.UpdateHardwareTypeTest do
  use EdgehogWeb.GraphqlCase, async: true

  alias Edgehog.Devices
  alias Edgehog.Devices.HardwareType

  import Edgehog.DevicesFixtures

  @moduletag :ported_to_ash

  describe "updateHardwareType mutation" do
    setup %{tenant: tenant} do
      hardware_type =
        hardware_type_fixture(tenant: tenant)
        |> Devices.load!(:part_number_strings)

      id = AshGraphql.Resource.encode_relay_id(hardware_type)

      %{hardware_type: hardware_type, id: id}
    end

    test "successfully updates with valid data", %{
      tenant: tenant,
      hardware_type: hardware_type,
      id: id
    } do
      result =
        update_hardware_type_mutation(
          tenant: tenant,
          id: id,
          name: "Updated Name",
          handle: "updatedhandle",
          part_numbers: "updated-1234"
        )

      hardware_type = extract_result!(result)

      assert %{
               "id" => _id,
               "name" => "Updated Name",
               "handle" => "updatedhandle",
               "partNumbers" => [
                 %{"partNumber" => "updated-1234"}
               ]
             } = hardware_type
    end

    test "supports partial updates", %{tenant: tenant, hardware_type: hardware_type, id: id} do
      %{part_number_strings: old_part_numbers, handle: old_handle} = hardware_type

      result =
        update_hardware_type_mutation(
          tenant: tenant,
          id: id,
          name: "Only Name Update"
        )

      hardware_type = extract_result!(result)

      assert %{
               "name" => "Only Name Update",
               "handle" => ^old_handle,
               "partNumbers" => part_numbers
             } = hardware_type

      assert length(part_numbers) == length(old_part_numbers)

      Enum.each(old_part_numbers, fn pn ->
        assert %{"partNumber" => pn} in part_numbers
      end)
    end

    test "manages part numbers correctly", %{tenant: tenant, hardware_type: hardware_type, id: id} do
      fixture = hardware_type_fixture(tenant: tenant, part_numbers: ["A", "B", "C"])

      result =
        update_hardware_type_mutation(
          tenant: tenant,
          id: id,
          part_numbers: ["B", "D"]
        )

      hardware_type = extract_result!(result)

      assert %{"partNumbers" => part_numbers} = hardware_type
      assert length(part_numbers) == 2
      assert %{"partNumber" => "B"} in part_numbers
      assert %{"partNumber" => "D"} in part_numbers
    end

    test "returns error for invalid handle", %{
      tenant: tenant,
      hardware_type: hardware_type,
      id: id
    } do
      result =
        update_hardware_type_mutation(
          tenant: tenant,
          id: id,
          handle: "123Invalid$"
        )

      assert %{fields: [:handle], message: "should only contain" <> _} =
               extract_error!(result)
    end

    test "returns error for empty part_numbers", %{
      tenant: tenant,
      hardware_type: hardware_type,
      id: id
    } do
      result =
        update_hardware_type_mutation(
          tenant: tenant,
          id: id,
          part_numbers: []
        )

      assert %{fields: [:part_numbers], message: "must have 1 or more items"} =
               extract_error!(result)
    end

    test "returns error for duplicate name", %{
      tenant: tenant,
      hardware_type: hardware_type,
      id: id
    } do
      fixture = hardware_type_fixture(tenant: tenant)

      result =
        update_hardware_type_mutation(
          tenant: tenant,
          id: id,
          name: fixture.name
        )

      assert %{fields: [:name], message: "has already been taken"} =
               extract_error!(result)
    end

    test "returns error for duplicate handle", %{
      tenant: tenant,
      hardware_type: hardware_type,
      id: id
    } do
      fixture = hardware_type_fixture(tenant: tenant)

      result =
        update_hardware_type_mutation(
          tenant: tenant,
          id: id,
          handle: fixture.handle
        )

      assert %{fields: [:handle], message: "has already been taken"} =
               extract_error!(result)
    end

    test "reassociates an existing HardwareTypePartNumber", %{
      tenant: tenant,
      hardware_type: hardware_type,
      id: id
    } do
      # TODO: see issue #228, this documents the current behaviour

      fixture = hardware_type_fixture(tenant: tenant, part_numbers: ["foo", "bar"])

      result =
        update_hardware_type_mutation(
          tenant: tenant,
          id: id,
          part_numbers: ["foo"]
        )

      _ = extract_result!(result)

      assert %HardwareType{part_number_strings: ["bar"]} =
               HardwareType
               |> Devices.get!(fixture.id, tenant: tenant)
               |> Devices.load!(:part_number_strings)
    end
  end

  defp update_hardware_type_mutation(opts) do
    default_document = """
    mutation UpdateHardwareType($id: ID!, $input: UpdateHardwareTypeInput!) {
      updateHardwareType(id: $id, input: $input) {
        result {
          id
          name
          handle
          partNumbers {
            partNumber
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    input =
      %{
        "handle" => opts[:handle],
        "name" => opts[:name],
        "partNumbers" => opts[:part_numbers]
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Enum.into(%{})

    variables = %{"id" => id, "input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_error!(result) do
    assert %{
             data: %{
               "updateHardwareType" => nil
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
               "updateHardwareType" => %{
                 "result" => hardware_type
               }
             }
           } = result

    assert hardware_type != nil

    hardware_type
  end
end
