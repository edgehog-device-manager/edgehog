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

defmodule EdgehogWeb.Schema.Mutation.UpdateBaseImageTest do
  use EdgehogWeb.ConnCase, async: true
  use Edgehog.BaseImagesStorageMockCase

  import Edgehog.BaseImagesFixtures

  describe "updateBaseImage mutation" do
    setup do
      {:ok, base_image: base_image_fixture()}
    end

    test "updates base image with valid data", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant,
      base_image: base_image
    } do
      default_tenant_locale = tenant.default_locale

      response =
        update_base_image_mutation(conn, api_path,
          base_image_id: base_image.id,
          starting_version_requirement: "~> 1.7.0-updated",
          description: localized_text(default_tenant_locale, "Updated description"),
          release_display_name: localized_text(default_tenant_locale, "Updated display name")
        )

      base_image = response["data"]["updateBaseImage"]["baseImage"]
      assert base_image["startingVersionRequirement"] == "~> 1.7.0-updated"
      assert base_image["description"] == "Updated description"
      assert base_image["releaseDisplayName"] == "Updated display name"
    end

    test "fails with invalid data", %{
      conn: conn,
      api_path: api_path,
      base_image: base_image
    } do
      response =
        update_base_image_mutation(conn, api_path,
          base_image_id: base_image.id,
          version: "invalid"
        )

      assert response["data"]["updateBaseImage"] == nil
      assert response["errors"] != nil
    end

    test "fails when not using the default tenant locale for the description", %{
      conn: conn,
      api_path: api_path,
      base_image: base_image
    } do
      response =
        update_base_image_mutation(conn, api_path,
          base_image_id: base_image.id,
          description: localized_text("it-IT", "Descrizione aggiornata")
        )

      assert response["data"]["updateBaseImage"] == nil
      assert %{"errors" => [%{"status_code" => 422, "code" => "not_default_locale"}]} = response
    end

    test "fails when not using the default tenant locale for the release display name", %{
      conn: conn,
      api_path: api_path,
      base_image: base_image
    } do
      response =
        update_base_image_mutation(conn, api_path,
          base_image_id: base_image.id,
          release_display_name: localized_text("it-IT", "Nome aggiornato")
        )

      assert response["data"]["updateBaseImage"] == nil
      assert %{"errors" => [%{"status_code" => 422, "code" => "not_default_locale"}]} = response
    end

    test "fails when trying to use a non-existing base image", %{
      conn: conn,
      api_path: api_path
    } do
      response = update_base_image_mutation(conn, api_path, base_image_id: "123456")

      assert %{"errors" => [%{"status_code" => 404, "code" => "not_found"}]} = response
    end
  end

  @query """
  mutation UpdateBaseImage($input: UpdateBaseImageInput!) {
    updateBaseImage(input: $input) {
      baseImage {
        version
        url
        startingVersionRequirement
        description
        releaseDisplayName
        baseImageCollection {
          handle
        }
      }
    }
  }
  """
  defp update_base_image_mutation(conn, api_path, opts) do
    base_image_id =
      Absinthe.Relay.Node.to_global_id(
        :base_image,
        opts[:base_image_id],
        EdgehogWeb.Schema
      )

    input =
      Enum.into(opts, %{})
      |> Map.put(:base_image_id, base_image_id)

    variables = %{input: input}

    conn = post(conn, api_path, query: @query, variables: variables)

    json_response(conn, 200)
  end

  defp localized_text(locale, text) do
    %{
      locale: locale,
      text: text
    }
  end
end
