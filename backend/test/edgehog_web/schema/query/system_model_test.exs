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

defmodule EdgehogWeb.Schema.Query.SystemModelTest do
  use EdgehogWeb.GraphqlCase, async: true

  @moduletag :ported_to_ash

  import Edgehog.DevicesFixtures

  alias Edgehog.Devices

  alias Edgehog.Devices.{
    SystemModel,
    SystemModelPartNumber
  }

  describe "systemModel query" do
    test "returns system model if present", %{tenant: tenant} do
      hardware_type = hardware_type_fixture(tenant: tenant)

      fixture =
        system_model_fixture(tenant: tenant, hardware_type_id: hardware_type.id)
        |> Edgehog.Devices.load!(:part_number_strings)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      result = system_model_query(tenant: tenant, id: id)

      refute Map.has_key?(result, :errors)
      assert %{data: %{"systemModel" => system_model}} = result
      assert system_model["name"] == fixture.name
      assert system_model["handle"] == fixture.handle
      assert length(system_model["partNumbers"]) == length(fixture.part_number_strings)

      Enum.each(fixture.part_number_strings, fn pn ->
        assert(%{"partNumber" => pn} in system_model["partNumbers"])
      end)

      assert system_model["hardwareType"]["id"] ==
               AshGraphql.Resource.encode_relay_id(hardware_type)
    end

    test "returns nil if non existing", %{tenant: tenant} do
      id = non_existing_system_model_id(tenant)
      result = system_model_query(tenant: tenant, id: id)
      assert %{data: %{"systemModel" => nil}} = result
    end
  end

  defp non_existing_system_model_id(tenant) do
    fixture = system_model_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Devices.destroy!(fixture)

    id
  end

  defp system_model_query(opts) do
    default_document = """
    query ($id: ID!) {
      systemModel(id: $id) {
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

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables = %{"id" => id}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end
end
