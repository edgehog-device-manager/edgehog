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

  import Edgehog.DevicesFixtures

  alias Edgehog.Devices
  alias Edgehog.Devices.SystemModel
  alias Edgehog.Devices.SystemModelPartNumber

  describe "systemModel query" do
    test "returns system model if present", %{tenant: tenant} do
      hardware_type = hardware_type_fixture(tenant: tenant)

      fixture =
        [
          tenant: tenant,
          hardware_type_id: hardware_type.id,
          picture_url: "https://example.com/image.jpg"
        ]
        |> system_model_fixture()
        |> Ash.load!(:part_number_strings)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      system_model =
        [tenant: tenant, id: id]
        |> system_model_query()
        |> extract_result!()

      assert system_model["name"] == fixture.name
      assert system_model["handle"] == fixture.handle
      assert system_model["pictureUrl"] == fixture.picture_url
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

  describe "systemModel localized descriptions" do
    setup %{tenant: tenant} do
      localized_descriptions = [
        %{language_tag: "en-US", value: "My Model"},
        %{language_tag: "it", value: "Il mio modello"},
        %{language_tag: "fr", value: "Mon modele"}
      ]

      system_model =
        system_model_fixture(tenant: tenant, localized_descriptions: localized_descriptions)

      id = AshGraphql.Resource.encode_relay_id(system_model)

      document = """
      query ($id: ID!, $preferredLanguageTags: [String!]) {
        systemModel(id: $id) {
          localizedDescriptions(preferredLanguageTags: $preferredLanguageTags) {
            languageTag
            value
          }
        }
      }
      """

      %{system_model: system_model, id: id, document: document}
    end

    test "returns all localized descriptions with no preferredLanguageTags", ctx do
      %{tenant: tenant, id: id, document: document} = ctx

      %{"localizedDescriptions" => localized_descriptions} =
        [tenant: tenant, id: id, document: document]
        |> system_model_query()
        |> extract_result!()

      assert length(localized_descriptions) == 3
      assert %{"languageTag" => "en-US", "value" => "My Model"} in localized_descriptions
      assert %{"languageTag" => "it", "value" => "Il mio modello"} in localized_descriptions
      assert %{"languageTag" => "fr", "value" => "Mon modele"} in localized_descriptions
    end

    test "returns filtered localized descriptions with preferredLanguageTags", ctx do
      %{tenant: tenant, id: id, document: document} = ctx
      preferred_language_tags = ["it", "fr"]

      %{"localizedDescriptions" => localized_descriptions} =
        [
          tenant: tenant,
          id: id,
          extra_variables: %{"preferredLanguageTags" => preferred_language_tags},
          document: document
        ]
        |> system_model_query()
        |> extract_result!()

      assert length(localized_descriptions) == 2
      assert %{"languageTag" => "it", "value" => "Il mio modello"} in localized_descriptions
      assert %{"languageTag" => "fr", "value" => "Mon modele"} in localized_descriptions
    end

    test "returns empty localized descriptions if no language tag matches exactly", ctx do
      %{tenant: tenant, id: id, document: document} = ctx
      preferred_language_tags = ["en-GB", "de"]

      %{"localizedDescriptions" => []} =
        [
          tenant: tenant,
          id: id,
          extra_variables: %{"preferredLanguageTags" => preferred_language_tags},
          document: document
        ]
        |> system_model_query()
        |> extract_result!()
    end
  end

  defp non_existing_system_model_id(tenant) do
    fixture = system_model_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end

  defp extract_result!(result) do
    assert %{data: %{"systemModel" => system_model}} = result

    refute :errors in Map.keys(result)
    assert system_model != nil

    system_model
  end

  defp system_model_query(opts) do
    default_document = """
    query ($id: ID!) {
      systemModel(id: $id) {
        name
        handle
        pictureUrl
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

    variables =
      opts
      |> Keyword.get(:extra_variables, %{})
      |> Map.put("id", id)

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end
end
