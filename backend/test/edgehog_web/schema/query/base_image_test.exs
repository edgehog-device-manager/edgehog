#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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
  use EdgehogWeb.ConnCase, async: true
  use Edgehog.BaseImagesStorageMockCase

  import Edgehog.BaseImagesFixtures

  alias Edgehog.BaseImages.BaseImage

  describe "baseImage query" do
    test "returns base image with all fields if present", %{conn: conn, api_path: api_path} do
      base_image = base_image_fixture()
      response = base_image_query(conn, api_path, base_image)

      assert response["data"]["baseImage"]["version"] == base_image.version
      assert response["data"]["baseImage"]["url"] == base_image.url

      assert response["data"]["baseImage"]["baseImageCollection"]["handle"] ==
               base_image.base_image_collection.handle
    end

    test "returns not found if non existing", %{conn: conn, api_path: api_path} do
      response = base_image_query(conn, api_path, 1_234_567)
      assert response["data"]["baseImage"] == nil
      assert [%{"code" => "not_found", "status_code" => 404}] = response["errors"]
    end
  end

  describe "baseImage query, description field" do
    test "returns the default locale", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      description = description_fixture([default_locale, "it-IT"])
      base_image = base_image_fixture(description: description)
      response = base_image_query(conn, api_path, base_image)

      assert response["data"]["baseImage"]["description"] == description[default_locale]
    end

    test "returns the locale in the accept-language header if present", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      description = description_fixture([default_locale, "it-IT"])
      base_image = base_image_fixture(description: description)

      response =
        conn
        |> accept_language("it-IT")
        |> base_image_query(api_path, base_image)

      assert response["data"]["baseImage"]["description"] == description["it-IT"]
    end

    test "returns the tenant's default locale for non existing locale", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      description = description_fixture([default_locale, "it-IT"])
      base_image = base_image_fixture(description: description)

      response =
        conn
        |> accept_language("fr-FR")
        |> base_image_query(api_path, base_image)

      assert response["data"]["baseImage"]["description"] == description[default_locale]
    end

    test "returns nil if both explicit and tenant default locale are missing", %{
      conn: conn,
      api_path: api_path
    } do
      description = description_fixture(["it-IT"])
      base_image = base_image_fixture(description: description)

      response =
        conn
        |> accept_language("fr-FR")
        |> base_image_query(api_path, base_image)

      assert response["data"]["baseImage"]["description"] == nil
    end
  end

  describe "baseImage query, release_display_name field" do
    test "returns the default locale", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      release_display_name = release_display_name_fixture([default_locale, "it-IT"])
      base_image = base_image_fixture(release_display_name: release_display_name)
      response = base_image_query(conn, api_path, base_image)

      assert response["data"]["baseImage"]["releaseDisplayName"] ==
               release_display_name[default_locale]
    end

    test "returns the locale in the accept-language header if present", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      release_display_name = release_display_name_fixture([default_locale, "it-IT"])
      base_image = base_image_fixture(release_display_name: release_display_name)

      response =
        conn
        |> accept_language("it-IT")
        |> base_image_query(api_path, base_image)

      assert response["data"]["baseImage"]["releaseDisplayName"] == release_display_name["it-IT"]
    end

    test "returns the tenant's default locale for non existing locale", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant
    } do
      default_locale = tenant.default_locale

      release_display_name = release_display_name_fixture([default_locale, "it-IT"])
      base_image = base_image_fixture(release_display_name: release_display_name)

      response =
        conn
        |> accept_language("fr-FR")
        |> base_image_query(api_path, base_image)

      assert response["data"]["baseImage"]["releaseDisplayName"] ==
               release_display_name[default_locale]
    end

    test "returns nil if both explicit and tenant default locale are missing", %{
      conn: conn,
      api_path: api_path
    } do
      description = description_fixture(["it-IT"])
      base_image = base_image_fixture(description: description)

      response =
        conn
        |> accept_language("fr-FR")
        |> base_image_query(api_path, base_image)

      assert response["data"]["baseImage"]["description"] == nil
    end
  end

  @query """
  query ($id: ID!) {
    baseImage(id: $id) {
      version
      url
      description
      releaseDisplayName
      baseImageCollection {
        handle
      }
    }
  }
  """
  defp base_image_query(conn, api_path, target, opts \\ [])

  defp base_image_query(conn, api_path, %BaseImage{} = base_image, opts) do
    base_image_query(conn, api_path, base_image.id, opts)
  end

  defp base_image_query(conn, api_path, id, opts) do
    id = Absinthe.Relay.Node.to_global_id(:base_image, id, EdgehogWeb.Schema)

    variables = %{id: id}
    query = Keyword.get(opts, :query, @query)
    conn = get(conn, api_path, query: query, variables: variables)

    json_response(conn, 200)
  end

  defp accept_language(conn, locale) do
    put_req_header(conn, "accept-language", locale)
  end

  defp description_fixture(locales) when is_list(locales) do
    for locale <- locales, into: %{} do
      {locale, "#{locale} description"}
    end
  end

  defp release_display_name_fixture(locales) when is_list(locales) do
    for locale <- locales, into: %{} do
      {locale, "#{locale} release display name"}
    end
  end
end
