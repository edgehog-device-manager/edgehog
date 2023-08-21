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

defmodule EdgehogWeb.Schema.Mutation.CreateBaseImageTest do
  use EdgehogWeb.ConnCase, async: true
  use Edgehog.BaseImagesStorageMockCase

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures

  describe "createBaseImage mutation" do
    setup do
      hardware_type = hardware_type_fixture()
      system_model = system_model_fixture(hardware_type)

      {:ok, base_image_collection: base_image_collection_fixture(system_model)}
    end

    test "creates base image with valid data", %{
      conn: conn,
      api_path: api_path,
      tenant: tenant,
      base_image_collection: base_image_collection
    } do
      default_tenant_locale = tenant.default_locale

      response =
        create_base_image_mutation(conn, api_path,
          base_image_collection_id: base_image_collection.id,
          version: "2.0.0",
          starting_version_requirement: "~> 1.0",
          description: localized_text(default_tenant_locale, "Description"),
          release_display_name: localized_text(default_tenant_locale, "Display name")
        )

      base_image = response["data"]["createBaseImage"]["baseImage"]
      assert base_image["version"] == "2.0.0"
      assert base_image["startingVersionRequirement"] == "~> 1.0"
      assert base_image["description"] == "Description"
      assert base_image["releaseDisplayName"] == "Display name"
      assert base_image["baseImageCollection"]["handle"] == base_image_collection.handle
    end

    test "fails with invalid data", %{
      conn: conn,
      api_path: api_path,
      base_image_collection: base_image_collection
    } do
      response =
        create_base_image_mutation(conn, api_path,
          base_image_collection_id: base_image_collection.id,
          version: "invalid"
        )

      assert response["data"]["createBaseImage"] == nil
      assert response["errors"] != nil
    end

    test "fails when not using the default tenant locale for the description", %{
      conn: conn,
      api_path: api_path,
      base_image_collection: base_image_collection
    } do
      response =
        create_base_image_mutation(conn, api_path,
          base_image_collection_id: base_image_collection.id,
          description: localized_text("it-IT", "Descrizione")
        )

      assert response["data"]["createBaseImage"] == nil
      assert %{"errors" => [%{"status_code" => 422, "code" => "not_default_locale"}]} = response
    end

    test "fails when not using the default tenant locale for the release display name", %{
      conn: conn,
      api_path: api_path,
      base_image_collection: base_image_collection
    } do
      response =
        create_base_image_mutation(conn, api_path,
          base_image_collection_id: base_image_collection.id,
          release_display_name: localized_text("it-IT", "Nome")
        )

      assert response["data"]["createBaseImage"] == nil
      assert %{"errors" => [%{"status_code" => 422, "code" => "not_default_locale"}]} = response
    end

    test "fails when trying to use a non-existing base image collection", %{
      conn: conn,
      api_path: api_path
    } do
      response = create_base_image_mutation(conn, api_path, base_image_collection_id: "123456")

      assert %{"errors" => [%{"status_code" => 404, "code" => "not_found"}]} = response
    end
  end

  @query """
  mutation CreateBaseImage($input: CreateBaseImageInput!) {
    createBaseImage(input: $input) {
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
  defp create_base_image_mutation(conn, api_path, opts) do
    base_image_collection_id =
      Absinthe.Relay.Node.to_global_id(
        :base_image_collection,
        opts[:base_image_collection_id],
        EdgehogWeb.Schema
      )

    fake_image = %Plug.Upload{path: "/tmp/ota.bin", filename: "ota.bin"}

    input =
      Enum.into(opts, %{
        version: unique_base_image_version(),
        file: "fake_image"
      })
      |> Map.put(:base_image_collection_id, base_image_collection_id)

    variables = %{input: input}

    conn = post(conn, api_path, query: @query, variables: variables, fake_image: fake_image)

    json_response(conn, 200)
  end

  defp localized_text(locale, text) do
    %{
      locale: locale,
      text: text
    }
  end
end
