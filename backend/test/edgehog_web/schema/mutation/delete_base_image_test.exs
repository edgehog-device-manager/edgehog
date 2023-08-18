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

defmodule EdgehogWeb.Schema.Mutation.DeleteBaseImageTest do
  use EdgehogWeb.ConnCase, async: true
  use Edgehog.BaseImagesStorageMockCase

  alias Edgehog.BaseImages
  import Edgehog.BaseImagesFixtures

  describe "deleteBaseImage mutation" do
    setup do
      {:ok, base_image: base_image_fixture()}
    end

    test "deletes existing base image", %{
      conn: conn,
      api_path: api_path,
      base_image: base_image
    } do
      response = delete_base_image_mutation(conn, api_path, base_image.id)
      assert response["data"]["deleteBaseImage"]["baseImage"]["version"] == base_image.version
      assert BaseImages.fetch_base_image(base_image.id) == {:error, :not_found}
    end

    test "fails with non-existing base image", %{
      conn: conn,
      api_path: api_path
    } do
      response = delete_base_image_mutation(conn, api_path, "123456")
      assert %{"errors" => [%{"status_code" => 404, "code" => "not_found"}]} = response
    end
  end

  @query """
  mutation DeleteBaseImage($input: DeleteBaseImageInput!) {
    deleteBaseImage(input: $input) {
      baseImage {
        id
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
  defp delete_base_image_mutation(conn, api_path, db_id) do
    base_image_id = Absinthe.Relay.Node.to_global_id(:base_image, db_id, EdgehogWeb.Schema)

    variables = %{input: %{base_image_id: base_image_id}}

    conn = post(conn, api_path, query: @query, variables: variables)

    json_response(conn, 200)
  end
end
