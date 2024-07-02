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

defmodule EdgehogWeb.Schema.Mutation.DeleteDeviceGroupTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.GroupsFixtures

  alias Edgehog.Groups.DeviceGroup
  require Ash.Query

  describe "deleteDeviceGroup query" do
    setup %{tenant: tenant} do
      device_group =
        device_group_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(device_group)

      %{device_group: device_group, id: id}
    end

    test "deletes a device group", %{tenant: tenant, id: id, device_group: fixture} do
      device_group =
        delete_device_group_mutation(tenant: tenant, id: id)
        |> extract_result!()

      assert device_group["handle"] == fixture.handle

      refute DeviceGroup
             |> Ash.Query.filter(id == ^fixture.id)
             |> Ash.Query.set_tenant(tenant)
             |> Ash.exists?()
    end

    test "fails with non-existing id", %{tenant: tenant} do
      id = non_existing_device_group_id(tenant)

      result = delete_device_group_mutation(tenant: tenant, id: id)

      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end
  end

  defp delete_device_group_mutation(opts) do
    default_document = """
    mutation DeleteDeviceGroup($id: ID!) {
      deleteDeviceGroup(id: $id) {
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

    document = Keyword.get(opts, :document, default_document)
    variables = %{"id" => id}
    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"deleteDeviceGroup" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{
             data: %{
               "deleteDeviceGroup" => %{
                 "result" => device_group
               }
             }
           } = result

    assert device_group != nil

    device_group
  end

  defp non_existing_device_group_id(tenant) do
    fixture = device_group_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end
end
