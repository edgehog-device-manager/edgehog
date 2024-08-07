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

defmodule EdgehogWeb.Schema.Query.HardwareTypeTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures

  describe "hardwareType query" do
    test "returns hardware type if present", %{tenant: tenant} do
      fixture =
        [tenant: tenant]
        |> hardware_type_fixture()
        |> Ash.load!(:part_number_strings)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      result = hardware_type_query(tenant: tenant, id: id)

      refute Map.has_key?(result, :errors)
      assert %{data: %{"hardwareType" => hardware_type}} = result
      assert hardware_type["name"] == fixture.name
      assert hardware_type["handle"] == fixture.handle
      assert length(hardware_type["partNumbers"]) == length(fixture.part_number_strings)

      Enum.each(fixture.part_number_strings, fn pn ->
        assert(%{"partNumber" => pn} in hardware_type["partNumbers"])
      end)
    end

    test "returns nil if non existing", %{tenant: tenant} do
      id = non_existing_hardware_type_id(tenant)
      result = hardware_type_query(tenant: tenant, id: id)
      assert %{data: %{"hardwareType" => nil}} = result
    end
  end

  defp non_existing_hardware_type_id(tenant) do
    fixture = hardware_type_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end

  defp hardware_type_query(opts) do
    default_document = """
    query ($id: ID!) {
      hardwareType(id: $id) {
        name
        handle
        partNumbers {
          partNumber
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
end
