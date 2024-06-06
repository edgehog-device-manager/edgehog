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

defmodule EdgehogWeb.Schema.Query.DeviceGroupsTest do
  use EdgehogWeb.GraphqlCase, async: true

  @moduletag :ported_to_ash

  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  describe "deviceGroups query" do
    test "returns empty device groups", %{tenant: tenant} do
      assert [] = device_groups_query(tenant: tenant) |> extract_result!()
    end

    test "returns device groups if present", %{tenant: tenant} do
      fixture = device_group_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(fixture)
      name = fixture.name
      handle = fixture.handle
      selector = fixture.selector

      assert [group] = device_groups_query(tenant: tenant, id: id) |> extract_result!()

      assert %{
               "handle" => ^handle,
               "name" => ^name,
               "selector" => ^selector
             } = group
    end

    test "returns only devices that match the selector", %{tenant: tenant} do
      _foo_group = device_group_fixture(tenant: tenant, name: "foo", selector: ~s<"foo" in tags>)
      _bar_group = device_group_fixture(tenant: tenant, name: "bar", selector: ~s<"bar" in tags>)

      foo_device =
        device_fixture(tenant: tenant)
        |> add_tags(["foo"])

      bar_device =
        device_fixture(tenant: tenant)
        |> add_tags(["bar"])

      foo_bar_device =
        device_fixture(tenant: tenant)
        |> add_tags(["foo", "bar"])

      _baz_device =
        device_fixture(tenant: tenant)
        |> add_tags(["baz"])

      document = """
      query {
        deviceGroups {
          count
          edges {
            node {
              name
              devices {
                id
              }
            }
          }
        }
      }
      """

      assert groups = device_groups_query(tenant: tenant, document: document) |> extract_result!()

      foo_group = Enum.find(groups, &(&1["name"] == "foo"))
      bar_group = Enum.find(groups, &(&1["name"] == "bar"))

      foo_device_ids =
        foo_group
        |> Map.fetch!("devices")
        |> Enum.map(& &1["id"])

      assert length(foo_device_ids) == 2

      assert AshGraphql.Resource.encode_relay_id(foo_device) in foo_device_ids
      assert AshGraphql.Resource.encode_relay_id(foo_bar_device) in foo_device_ids

      bar_device_ids =
        bar_group
        |> Map.fetch!("devices")
        |> Enum.map(& &1["id"])

      assert length(bar_device_ids) == 2

      assert AshGraphql.Resource.encode_relay_id(bar_device) in bar_device_ids
      assert AshGraphql.Resource.encode_relay_id(foo_bar_device) in bar_device_ids
    end
  end

  defp device_groups_query(opts) do
    default_document = """
    query {
      deviceGroups {
        count
        edges {
          node {
            id
            name
            handle
            selector
          }
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{data: %{"deviceGroups" => %{"count" => count, "edges" => edges}}} = result
    refute :errors in Map.keys(result)

    device_groups = Enum.map(edges, & &1["node"])

    assert length(device_groups) == count

    device_groups
  end
end
