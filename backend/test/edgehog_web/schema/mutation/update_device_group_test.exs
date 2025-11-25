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

defmodule EdgehogWeb.Schema.Mutation.UpdateDeviceGroupTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.GroupsFixtures

  describe "updateDeviceGroup query" do
    setup %{tenant: tenant} do
      device_group = device_group_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(device_group)

      {:ok, device_group: device_group, id: id}
    end

    test "successfully updates with valid data", %{
      tenant: tenant,
      id: id
    } do
      result =
        update_device_group_mutation(
          tenant: tenant,
          id: id,
          name: "Updated Name",
          handle: "updatedhandle",
          selector: ~s<"updated" in tags>
        )

      device_group = extract_result!(result)

      assert %{
               "id" => _id,
               "name" => "Updated Name",
               "handle" => "updatedhandle",
               "selector" => ~s<"updated" in tags>
             } = device_group
    end

    test "supports partial updates", %{tenant: tenant, device_group: device_group, id: id} do
      %{handle: old_handle, selector: old_selector} = device_group

      result =
        update_device_group_mutation(
          tenant: tenant,
          id: id,
          name: "Only Name Update"
        )

      device_group = extract_result!(result)

      assert %{
               "name" => "Only Name Update",
               "handle" => ^old_handle,
               "selector" => ^old_selector
             } = device_group
    end

    test "returns error for invalid handle", %{tenant: tenant, id: id} do
      result =
        update_device_group_mutation(
          tenant: tenant,
          id: id,
          handle: "123Invalid$"
        )

      assert %{fields: [:handle], message: "should only contain" <> _} = extract_error!(result)
    end

    test "returns error for invalid selector", %{tenant: tenant, id: id} do
      result =
        update_device_group_mutation(
          tenant: tenant,
          id: id,
          selector: "foobaz"
        )

      assert %{fields: [:selector], message: "failed to be parsed" <> _} = extract_error!(result)
    end

    test "returns error for duplicate name", %{
      tenant: tenant,
      id: id
    } do
      fixture = device_group_fixture(tenant: tenant)

      result =
        update_device_group_mutation(
          tenant: tenant,
          id: id,
          name: fixture.name
        )

      assert %{fields: [:name], message: "has already been taken"} = extract_error!(result)
    end

    test "returns error for duplicate handle", %{
      tenant: tenant,
      id: id
    } do
      fixture = device_group_fixture(tenant: tenant)

      result =
        update_device_group_mutation(
          tenant: tenant,
          id: id,
          handle: fixture.handle
        )

      assert %{fields: [:handle], message: "has already been taken"} =
               extract_error!(result)
    end

    test "returns error for non-existing device group", %{tenant: tenant} do
      id = non_existing_device_group_id(tenant)

      result =
        update_device_group_mutation(
          tenant: tenant,
          id: id,
          name: "Updated"
        )

      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end
  end

  defp update_device_group_mutation(opts) do
    default_document = """
    mutation UpdateDeviceGroup($id: ID!, $input: UpdateDeviceGroupInput!) {
      updateDeviceGroup(id: $id, input: $input) {
        result {
          id
          name
          handle
          selector
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    input =
      %{
        "name" => opts[:name],
        "handle" => opts[:handle],
        "selector" => opts[:selector]
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Map.new()

    variables = %{"id" => id, "input" => input}
    document = Keyword.get(opts, :document, default_document)
    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"updateDeviceGroup" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{
             data: %{
               "updateDeviceGroup" => %{
                 "result" => device_group
               }
             }
           } = result

    assert device_group

    device_group
  end

  defp non_existing_device_group_id(tenant) do
    fixture = device_group_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end
end
