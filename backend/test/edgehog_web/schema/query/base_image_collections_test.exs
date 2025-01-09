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

defmodule EdgehogWeb.Schema.Query.BaseImageCollectionsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures

  describe "baseImageCollections field" do
    test "returns empty base image collections", %{tenant: tenant} do
      assert [] = [tenant: tenant] |> base_image_collections_query() |> extract_result!()
    end

    test "returns base image collections if they're present", %{tenant: tenant} do
      system_model = system_model_fixture(tenant: tenant)

      fixture =
        base_image_collection_fixture(
          tenant: tenant,
          system_model_id: system_model.id
        )

      assert [base_image_collection] =
               [tenant: tenant] |> base_image_collections_query() |> extract_result!()

      assert base_image_collection["name"] == fixture.name
      assert base_image_collection["handle"] == fixture.handle

      assert base_image_collection["systemModel"]["id"] ==
               AshGraphql.Resource.encode_relay_id(system_model)
    end
  end

  defp base_image_collections_query(opts) do
    default_document =
      """
      query BaseImageCollections($filter: BaseImageCollectionFilterInput, $sort: [BaseImageCollectionSortInput]) {
        baseImageCollections(filter: $filter, sort: $sort) {
          count
          edges {
            node {
              name
              handle
              systemModel {
                id
              }
            }
          }
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    variables =
      %{
        "filter" => opts[:filter],
        "sort" => opts[:sort] || []
      }

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{data: %{"baseImageCollections" => %{"count" => count, "edges" => edges}}} = result
    refute :errors in Map.keys(result)

    base_image_collections = Enum.map(edges, & &1["node"])

    assert length(base_image_collections) == count

    base_image_collections
  end
end
