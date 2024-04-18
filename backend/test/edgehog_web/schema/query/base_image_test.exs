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
  use Edgehog.BaseImagesStorageMockCase

  import Edgehog.BaseImagesFixtures

  alias Edgehog.BaseImages.BaseImage

  @moduletag :ported_to_ash

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

    variables = %{"id" => id}

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
