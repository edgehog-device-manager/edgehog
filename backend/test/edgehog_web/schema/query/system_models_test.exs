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

defmodule EdgehogWeb.Schema.Query.SystemModelsTest do
  use EdgehogWeb.GraphqlCase, async: true

  @moduletag :ported_to_ash

  import Edgehog.DevicesFixtures

  alias Edgehog.Devices.{
    SystemModel,
    SystemModelPartNumber
  }

  describe "systemModels query" do
    test "returns empty system models", %{tenant: tenant} do
      assert %{data: %{"systemModels" => []}} == system_models_query(tenant: tenant)
    end

    test "returns system models if they're present", %{tenant: tenant} do
      hardware_type = hardware_type_fixture(tenant: tenant)

      fixture =
        system_model_fixture(tenant: tenant, hardware_type_id: hardware_type.id)
        |> Edgehog.Devices.load!(:part_number_strings)

      assert %{data: %{"systemModels" => [system_model]}} = system_models_query(tenant: tenant)

      assert system_model["name"] == fixture.name
      assert system_model["handle"] == fixture.handle
      assert length(system_model["partNumbers"]) == length(fixture.part_number_strings)

      Enum.each(fixture.part_number_strings, fn pn ->
        assert(%{"partNumber" => pn} in system_model["partNumbers"])
      end)

      assert system_model["hardwareType"]["id"] ==
               AshGraphql.Resource.encode_relay_id(hardware_type)
    end

    test "allows filtering", %{tenant: tenant} do
      _ = system_model_fixture(tenant: tenant, handle: "foo")
      _ = system_model_fixture(tenant: tenant, handle: "bar", part_numbers: ["123-bar"])
      _ = system_model_fixture(tenant: tenant, handle: "baz")

      filter = %{
        "or" => [
          %{"handle" => %{"eq" => "foo"}},
          %{"partNumbers" => %{"partNumber" => %{"eq" => "123-bar"}}}
        ]
      }

      assert %{data: %{"systemModels" => system_models}} =
               system_models_query(tenant: tenant, filter: filter)

      assert length(system_models) == 2
      assert "foo" in Enum.map(system_models, & &1["handle"])
      assert "bar" in Enum.map(system_models, & &1["handle"])
      refute "baz" in Enum.map(system_models, & &1["handle"])
    end

    test "allows sorting", %{tenant: tenant} do
      _ = system_model_fixture(tenant: tenant, handle: "3")
      _ = system_model_fixture(tenant: tenant, handle: "2")
      _ = system_model_fixture(tenant: tenant, handle: "1")

      sort = [
        %{"field" => "HANDLE", "order" => "ASC"}
      ]

      assert %{data: %{"systemModels" => system_models}} =
               system_models_query(tenant: tenant, sort: sort)

      assert [
               %{"handle" => "1"},
               %{"handle" => "2"},
               %{"handle" => "3"}
             ] = system_models
    end
  end

  defp system_models_query(opts) do
    default_document =
      """
      query SystemModels($filter: SystemModelFilterInput, $sort: [SystemModelSortInput]) {
        systemModels(filter: $filter, sort: $sort) {
          name
          handle
          partNumbers {
            partNumber
          }
          hardwareType {
            id
          }
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    filter = opts[:filter]
    sort = opts[:sort]

    variables =
      %{
        "filter" => opts[:filter],
        "sort" => opts[:sort] || []
      }

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end
end
