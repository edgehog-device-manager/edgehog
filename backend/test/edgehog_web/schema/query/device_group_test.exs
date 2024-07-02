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

defmodule EdgehogWeb.Schema.Query.DeviceGroupTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  alias Edgehog.Groups.DeviceGroup

  describe "deviceGroup query" do
    test "returns nil for non existing device group", %{tenant: tenant} do
      id = non_existing_device_group_id(tenant)
      result = device_group_query(tenant: tenant, id: id)
      assert %{data: %{"deviceGroup" => nil}} = result
    end

    test "returns device group if it's present", %{tenant: tenant} do
      fixture = device_group_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      result =
        device_group_query(tenant: tenant, id: id)
        |> extract_result!()

      assert result["name"] == fixture.name
      assert result["handle"] == fixture.handle
      assert result["selector"] == fixture.selector
    end

    test "returns only devices that match the selector", %{tenant: tenant} do
      selector = ~s<("foo" in tags and "bar" not in tags) or "baz" in tags>

      fixture = device_group_fixture(tenant: tenant, selector: selector)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      foo_device =
        device_fixture(tenant: tenant)
        |> add_tags(["foo"])

      foo_bar_device =
        device_fixture(tenant: tenant)
        |> add_tags(["foo", "bar"])

      baz_device =
        device_fixture(tenant: tenant)
        |> add_tags(["baz"])

      document = """
      query ($id: ID!) {
        deviceGroup(id: $id) {
          devices {
            id
          }
        }
      }
      """

      assert %{"devices" => devices} =
               device_group_query(tenant: tenant, id: id, document: document)
               |> extract_result!()

      assert length(devices) == 2
      device_ids = Enum.map(devices, &Map.get(&1, "id"))

      assert AshGraphql.Resource.encode_relay_id(foo_device) in device_ids
      assert AshGraphql.Resource.encode_relay_id(baz_device) in device_ids
      refute AshGraphql.Resource.encode_relay_id(foo_bar_device) in device_ids
    end
  end

  defp non_existing_device_group_id(tenant) do
    fixture = device_group_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end

  defp device_group_query(opts) do
    default_document = """
    query ($id: ID!) {
      deviceGroup(id: $id) {
        name
        handle
        selector
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables = %{"id" => id}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"deviceGroup" => device_group}} = result
    assert device_group != nil

    device_group
  end
end
