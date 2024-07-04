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

defmodule EdgehogWeb.Schema.Query.HardwareTypesTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures

  describe "hardwareTypes query" do
    test "returns empty hardware types", %{tenant: tenant} do
      assert %{data: %{"hardwareTypes" => []}} == hardware_types_query(tenant: tenant)
    end

    test "returns hardware types if they're present", %{tenant: tenant} do
      fixture =
        [tenant: tenant]
        |> hardware_type_fixture()
        |> Ash.load!(:part_number_strings)

      assert %{data: %{"hardwareTypes" => [hardware_type]}} = hardware_types_query(tenant: tenant)

      assert hardware_type["name"] == fixture.name
      assert hardware_type["handle"] == fixture.handle
      assert length(hardware_type["partNumbers"]) == length(fixture.part_number_strings)

      Enum.each(fixture.part_number_strings, fn pn ->
        assert(%{"partNumber" => pn} in hardware_type["partNumbers"])
      end)
    end

    test "allows filtering", %{tenant: tenant} do
      _ = hardware_type_fixture(tenant: tenant, handle: "foo")
      _ = hardware_type_fixture(tenant: tenant, handle: "bar", part_numbers: ["123-bar"])
      _ = hardware_type_fixture(tenant: tenant, handle: "baz")

      filter = %{
        "or" => [
          %{"handle" => %{"eq" => "foo"}},
          %{"partNumbers" => %{"partNumber" => %{"eq" => "123-bar"}}}
        ]
      }

      assert %{data: %{"hardwareTypes" => hardware_types}} =
               hardware_types_query(tenant: tenant, filter: filter)

      assert length(hardware_types) == 2
      assert "foo" in Enum.map(hardware_types, & &1["handle"])
      assert "bar" in Enum.map(hardware_types, & &1["handle"])
      refute "baz" in Enum.map(hardware_types, & &1["handle"])
    end

    test "allows sorting", %{tenant: tenant} do
      _ = hardware_type_fixture(tenant: tenant, handle: "3")
      _ = hardware_type_fixture(tenant: tenant, handle: "2")
      _ = hardware_type_fixture(tenant: tenant, handle: "1")

      sort = [
        %{"field" => "HANDLE", "order" => "ASC"}
      ]

      assert %{data: %{"hardwareTypes" => hardware_types}} =
               hardware_types_query(tenant: tenant, sort: sort)

      assert [
               %{"handle" => "1"},
               %{"handle" => "2"},
               %{"handle" => "3"}
             ] = hardware_types
    end
  end

  defp hardware_types_query(opts) do
    default_document =
      """
      query HardwareTypes($filter: HardwareTypeFilterInput, $sort: [HardwareTypeSortInput]) {
        hardwareTypes(filter: $filter, sort: $sort) {
          name
          handle
          partNumbers {
            partNumber
          }
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    variables =
      %{
        "filter" => opts[:filter],
        "sort" => opts[:sort] || []
      }

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end
end
