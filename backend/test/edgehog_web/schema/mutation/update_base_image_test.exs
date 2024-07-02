#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.UpdateBaseImageTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures

  describe "updateBaseImage mutation" do
    setup %{tenant: tenant} do
      base_image = base_image_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(base_image)

      %{base_image: base_image, id: id}
    end

    test "updates base image with valid data", %{
      tenant: tenant,
      base_image: base_image,
      id: id
    } do
      result =
        update_base_image_mutation(
          tenant: tenant,
          id: id,
          starting_version_requirement: "~> 1.7.0-updated"
        )

      base_image = extract_result!(result)

      assert %{
               "id" => ^id,
               "startingVersionRequirement" => "~> 1.7.0-updated"
             } = base_image
    end

    test "allows updating localized descriptions", %{tenant: tenant} do
      initial_localized_descriptions = [
        %{language_tag: "en", value: "Description"},
        %{language_tag: "it", value: "Descrizione"}
      ]

      fixture =
        base_image_fixture(
          tenant: tenant,
          localized_descriptions: initial_localized_descriptions
        )

      id = AshGraphql.Resource.encode_relay_id(fixture)

      updated_localized_descriptions = [
        # nil value, so it will be removed
        %{"languageTag" => "en", "value" => nil},
        %{"languageTag" => "it", "value" => "Nuova descrizione"},
        %{"languageTag" => "bs", "value" => "Opis"}
      ]

      result =
        update_base_image_mutation(
          tenant: tenant,
          id: id,
          localized_descriptions: updated_localized_descriptions
        )

      assert %{"localizedDescriptions" => localized_descriptions} = extract_result!(result)
      assert length(localized_descriptions) == 2
      assert %{"languageTag" => "it", "value" => "Nuova descrizione"} in localized_descriptions
      assert %{"languageTag" => "bs", "value" => "Opis"} in localized_descriptions
    end

    test "allows updating localized release display names", %{tenant: tenant} do
      initial_localized_release_display_names = [
        %{language_tag: "en", value: "Release display name"},
        %{language_tag: "it", value: "Nome del rilascio"}
      ]

      fixture =
        base_image_fixture(
          tenant: tenant,
          localized_release_display_names: initial_localized_release_display_names
        )

      id = AshGraphql.Resource.encode_relay_id(fixture)

      updated_localized_release_display_names = [
        # nil value, so it will be removed
        %{"languageTag" => "en", "value" => nil},
        %{"languageTag" => "it", "value" => "Nuovo nome del rilascio"},
        %{"languageTag" => "bs", "value" => "Ime"}
      ]

      result =
        update_base_image_mutation(
          tenant: tenant,
          id: id,
          localized_release_display_names: updated_localized_release_display_names
        )

      assert %{"localizedReleaseDisplayNames" => localized_release_display_names} =
               extract_result!(result)

      assert length(localized_release_display_names) == 2

      assert %{
               "languageTag" => "it",
               "value" => "Nuovo nome del rilascio"
             } in localized_release_display_names

      assert %{"languageTag" => "bs", "value" => "Ime"} in localized_release_display_names
    end

    test "returns error for invalid starting version requirement", %{
      tenant: tenant,
      base_image: base_image,
      id: id
    } do
      result =
        update_base_image_mutation(
          tenant: tenant,
          id: id,
          starting_version_requirement: "invalid"
        )

      assert %{
               fields: [:starting_version_requirement],
               message: "is not a valid version requirement"
             } = extract_error!(result)
    end

    test "fails when trying to use a non-existing base image", %{tenant: tenant} do
      id = non_existing_base_image_id(tenant)

      result =
        update_base_image_mutation(
          tenant: tenant,
          id: id,
          starting_version_requirement: "~> 1.7.0-updated"
        )

      assert %{fields: [:id], message: "could not be found" <> _} =
               extract_error!(result)
    end
  end

  defp update_base_image_mutation(opts) do
    default_document = """
    mutation UpdateBaseImage($id: ID!, $input: UpdateBaseImageInput!) {
      updateBaseImage(id: $id, input: $input) {
        result {
          id
          version
          url
          localizedDescriptions {
            languageTag
            value
          }
          localizedReleaseDisplayNames {
            languageTag
            value
          }
          startingVersionRequirement
          baseImageCollection {
            id
            handle
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    input =
      %{
        "startingVersionRequirement" => opts[:starting_version_requirement],
        "localizedDescriptions" => opts[:localized_descriptions],
        "localizedReleaseDisplayNames" => opts[:localized_release_display_names]
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Enum.into(%{})

    variables = %{"id" => id, "input" => input}

    document = Keyword.get(opts, :document, default_document)

    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"updateBaseImage" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateBaseImage" => %{
                 "result" => base_image
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert base_image != nil

    base_image
  end

  defp non_existing_base_image_id(tenant) do
    fixture = base_image_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture, action: :destroy_fixture)

    id
  end
end
