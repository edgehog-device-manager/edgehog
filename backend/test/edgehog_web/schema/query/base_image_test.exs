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

defmodule EdgehogWeb.Schema.Query.BaseImageTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures

  alias Edgehog.BaseImages.BaseImage

  describe "baseImage query" do
    setup %{tenant: tenant} do
      base_image =
        base_image_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(base_image)

      %{base_image: base_image, id: id}
    end

    test "returns base image with all fields if present", %{
      tenant: tenant,
      base_image: fixture,
      id: id
    } do
      base_image = base_image_query(tenant: tenant, id: id) |> extract_result!()

      assert base_image["id"] == id
      assert base_image["version"] == fixture.version
      assert base_image["startingVersionRequirement"] == fixture.starting_version_requirement
      assert base_image["url"] == fixture.url
      assert base_image["baseImageCollection"]["handle"] == fixture.base_image_collection.handle
    end

    test "returns nil if non existing", %{tenant: tenant} do
      id = non_existing_base_image_id(tenant)

      result = base_image_query(tenant: tenant, id: id)

      assert result == %{data: %{"baseImage" => nil}}
    end
  end

  describe "baseImage localized descriptions" do
    setup %{tenant: tenant} do
      localized_descriptions = [
        %{language_tag: "en-US", value: "My Base Image"},
        %{language_tag: "it", value: "La mia Base Image"},
        %{language_tag: "fr", value: "Mon Base Image"}
      ]

      base_image =
        base_image_fixture(tenant: tenant, localized_descriptions: localized_descriptions)

      id = AshGraphql.Resource.encode_relay_id(base_image)

      document = """
      query ($id: ID!, $preferredLanguageTags: [String!]) {
        baseImage(id: $id) {
          localizedDescriptions(preferredLanguageTags: $preferredLanguageTags) {
            languageTag
            value
          }
        }
      }
      """

      %{base_image: base_image, id: id, document: document}
    end

    test "returns all localized descriptions with no preferredLanguageTags", ctx do
      %{tenant: tenant, id: id, document: document} = ctx

      %{"localizedDescriptions" => localized_descriptions} =
        base_image_query(
          tenant: tenant,
          id: id,
          document: document
        )
        |> extract_result!()

      assert length(localized_descriptions) == 3
      assert %{"languageTag" => "en-US", "value" => "My Base Image"} in localized_descriptions
      assert %{"languageTag" => "it", "value" => "La mia Base Image"} in localized_descriptions
      assert %{"languageTag" => "fr", "value" => "Mon Base Image"} in localized_descriptions
    end

    test "returns filtered localized descriptions with preferredLanguageTags", ctx do
      %{tenant: tenant, id: id, document: document} = ctx
      preferred_language_tags = ["it", "fr"]

      %{"localizedDescriptions" => localized_descriptions} =
        base_image_query(
          tenant: tenant,
          id: id,
          extra_variables: %{"preferredLanguageTags" => preferred_language_tags},
          document: document
        )
        |> extract_result!()

      assert length(localized_descriptions) == 2
      assert %{"languageTag" => "it", "value" => "La mia Base Image"} in localized_descriptions
      assert %{"languageTag" => "fr", "value" => "Mon Base Image"} in localized_descriptions
    end

    test "returns empty localized descriptions if no language tag matches exactly", ctx do
      %{tenant: tenant, id: id, document: document} = ctx
      preferred_language_tags = ["en-GB", "de"]

      %{"localizedDescriptions" => []} =
        base_image_query(
          tenant: tenant,
          id: id,
          extra_variables: %{"preferredLanguageTags" => preferred_language_tags},
          document: document
        )
        |> extract_result!()
    end
  end

  describe "baseImage localized release display names" do
    setup %{tenant: tenant} do
      localized_release_display_names = [
        %{language_tag: "en-US", value: "Initial version"},
        %{language_tag: "it", value: "Versione iniziale"},
        %{language_tag: "fr", value: "Version initiale"}
      ]

      base_image =
        base_image_fixture(
          tenant: tenant,
          localized_release_display_names: localized_release_display_names
        )

      id = AshGraphql.Resource.encode_relay_id(base_image)

      document = """
      query ($id: ID!, $preferredLanguageTags: [String!]) {
        baseImage(id: $id) {
          localizedReleaseDisplayNames(preferredLanguageTags: $preferredLanguageTags) {
            languageTag
            value
          }
        }
      }
      """

      %{base_image: base_image, id: id, document: document}
    end

    test "returns all localized release display names with no preferredLanguageTags", ctx do
      %{tenant: tenant, id: id, document: document} = ctx

      %{"localizedReleaseDisplayNames" => localized_release_display_names} =
        base_image_query(
          tenant: tenant,
          id: id,
          document: document
        )
        |> extract_result!()

      assert length(localized_release_display_names) == 3

      assert %{"languageTag" => "en-US", "value" => "Initial version"} in localized_release_display_names

      assert %{"languageTag" => "it", "value" => "Versione iniziale"} in localized_release_display_names

      assert %{"languageTag" => "fr", "value" => "Version initiale"} in localized_release_display_names
    end

    test "returns filtered localized release display names with preferredLanguageTags", ctx do
      %{tenant: tenant, id: id, document: document} = ctx
      preferred_language_tags = ["it", "fr"]

      %{"localizedReleaseDisplayNames" => localized_release_display_names} =
        base_image_query(
          tenant: tenant,
          id: id,
          extra_variables: %{"preferredLanguageTags" => preferred_language_tags},
          document: document
        )
        |> extract_result!()

      assert length(localized_release_display_names) == 2

      assert %{
               "languageTag" => "it",
               "value" => "Versione iniziale"
             } in localized_release_display_names

      assert %{
               "languageTag" => "fr",
               "value" => "Version initiale"
             } in localized_release_display_names
    end

    test "returns empty localized release display names if no language tag matches exactly",
         ctx do
      %{tenant: tenant, id: id, document: document} = ctx
      preferred_language_tags = ["en-GB", "de"]

      %{"localizedReleaseDisplayNames" => []} =
        base_image_query(
          tenant: tenant,
          id: id,
          extra_variables: %{"preferredLanguageTags" => preferred_language_tags},
          document: document
        )
        |> extract_result!()
    end
  end

  defp base_image_query(opts) do
    default_document = """
    query ($id: ID!) {
      baseImage(id: $id) {
        id
        url
        version
        startingVersionRequirement
        baseImageCollection {
          handle
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables =
      opts
      |> Keyword.get(:extra_variables, %{})
      |> Map.merge(%{"id" => id})

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "baseImage" => base_image
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
