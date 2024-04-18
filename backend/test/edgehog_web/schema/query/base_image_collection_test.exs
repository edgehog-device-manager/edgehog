#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.BaseImageCollectionTest do
  use EdgehogWeb.GraphqlCase, async: true
  use Edgehog.BaseImagesStorageMockCase

  import Edgehog.DevicesFixtures
  import Edgehog.BaseImagesFixtures

  @moduletag :ported_to_ash

  describe "baseImageCollection field" do
    test "returns base image collection if present", %{tenant: tenant} do
      system_model = system_model_fixture(tenant: tenant)

      fixture =
        base_image_collection_fixture(
          tenant: tenant,
          system_model_id: system_model.id
        )

      id = AshGraphql.Resource.encode_relay_id(fixture)

      base_image_collection =
        base_image_collection_query(tenant: tenant, id: id) |> extract_result!()

      assert base_image_collection["name"] == fixture.name
      assert base_image_collection["handle"] == fixture.handle

      assert base_image_collection["systemModel"]["id"] ==
               AshGraphql.Resource.encode_relay_id(system_model)
    end

    test "returns nil if non existing", %{tenant: tenant} do
      id = non_existing_base_image_collection_id(tenant)
      result = base_image_collection_query(tenant: tenant, id: id)
      assert result == %{data: %{"baseImageCollection" => nil}}
    end

    test "returns associated base images", %{tenant: tenant} do
      _other_base_image = base_image_fixture(tenant: tenant, version: "1.0.0")
      base_image_collection = base_image_collection_fixture(tenant: tenant)

      base_image =
        base_image_fixture(
          tenant: tenant,
          version: "2.0.0",
          base_image_collection_id: base_image_collection.id
        )

      base_image_collection_id = AshGraphql.Resource.encode_relay_id(base_image_collection)
      base_image_id = AshGraphql.Resource.encode_relay_id(base_image)

      result = base_image_collection_query(tenant: tenant, id: base_image_collection_id)

      assert %{
               "baseImages" => [
                 %{
                   "id" => ^base_image_id,
                   "version" => "2.0.0"
                 }
               ]
             } = extract_result!(result)
    end
  end

  defp non_existing_base_image_collection_id(tenant) do
    fixture = base_image_collection_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end

  defp base_image_collection_query(opts) do
    default_document = """
    query ($id: ID!) {
      baseImageCollection(id: $id) {
        name
        handle
        baseImages {
          id
          version
        }
        systemModel {
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

  defp extract_result!(result) do
    assert %{
             data: %{
               "baseImageCollection" => base_image_collection
             }
           } = result

    refute Map.get(result, :errors)

    assert base_image_collection != nil

    base_image_collection
  end
end
