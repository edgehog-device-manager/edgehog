#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.CreateDeviceGroupTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  describe "createDeviceGroup mutation" do
    test "creates device group with valid data", %{tenant: tenant} do
      device =
        [tenant: tenant]
        |> device_fixture()
        |> add_tags(["foo"])

      device_id = AshGraphql.Resource.encode_relay_id(device)

      _other_device =
        [tenant: tenant]
        |> device_fixture()
        |> add_tags(["bar"])

      name = "Foos"
      handle = "foos"
      selector = ~s<"foo" in tags>

      device_group =
        [tenant: tenant, name: name, handle: handle, selector: selector]
        |> create_device_group_mutation()
        |> extract_result!()

      assert %{
               "name" => ^name,
               "handle" => ^handle,
               "devices" => [%{"id" => ^device_id}]
             } = device_group
    end

    test "fails with invalid handle", %{tenant: tenant} do
      assert %{fields: [:handle], message: "should only contain" <> _} =
               [tenant: tenant, handle: "123Invalid$"]
               |> create_device_group_mutation()
               |> extract_error!()
    end

    test "fails with invalid selector", %{tenant: tenant} do
      assert %{fields: [:selector], message: "failed to be parsed" <> _} =
               [tenant: tenant, selector: "not a selector"]
               |> create_device_group_mutation()
               |> extract_error!()
    end
  end

  defp create_device_group_mutation(opts) do
    default_document = """
    mutation CreateDeviceGroup($input: CreateDeviceGroupInput!) {
      createDeviceGroup(input: $input) {
        result {
          id
          name
          handle
          selector
          devices {
            id
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    input = %{
      "handle" => opts[:handle] || unique_device_group_handle(),
      "name" => opts[:name] || unique_device_group_name(),
      "selector" => opts[:selector] || unique_device_group_selector()
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_error!(result) do
    assert %{
             data: %{
               "createDeviceGroup" => nil
             },
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createDeviceGroup" => %{
                 "result" => device_group
               }
             }
           } = result

    refute :errors in Map.keys(result)

    assert device_group != nil

    device_group
  end
end
