#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.RemoveDeviceTagsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures

  @moduletag :ported_to_ash

  describe "removeDeviceTags mutation" do
    setup %{tenant: tenant} do
      device =
        device_fixture(tenant: tenant)
        |> Ash.Changeset.for_update(:add_tags, %{tags: ["foo", "bar"]})
        |> Ash.update!()

      id = AshGraphql.Resource.encode_relay_id(device)

      %{device: device, id: id}
    end

    test "successfully removes tags", %{tenant: tenant, id: id} do
      result = remove_device_tags_mutation(tenant: tenant, id: id, tags: ["foo"])

      assert [%{"name" => "bar"}] = extract_result!(result)
    end

    test "normalizes tag names", %{tenant: tenant, id: id} do
      result = remove_device_tags_mutation(tenant: tenant, id: id, tags: ["FOO", "   bar "])

      assert [] = extract_result!(result)
    end

    test "is idempotent and works with non-existing tags", ctx do
      %{tenant: tenant, device: device, id: id} = ctx

      device
      |> Ash.Changeset.for_update(:remove_tags, %{tags: ["bar"]})
      |> Ash.update!()

      result =
        remove_device_tags_mutation(tenant: tenant, id: id, tags: ["bar", "baz"])

      assert [%{"name" => "foo"}] = extract_result!(result)
    end

    test "fails with empty tags", %{tenant: tenant, id: id} do
      result = remove_device_tags_mutation(tenant: tenant, id: id, tags: [])
      assert %{fields: [:tags], message: "must have 1 or more items"} = extract_error!(result)
    end

    test "fails with invalid tag after normalization", %{tenant: tenant, id: id} do
      result = remove_device_tags_mutation(tenant: tenant, id: id, tags: ["     "])
      assert %{fields: [:tags], message: "no nil values"} = extract_error!(result)
    end

    test "fails with non-existing id", %{tenant: tenant} do
      id = non_existing_device_id(tenant)
      result = remove_device_tags_mutation(tenant: tenant, id: id, tags: ["foo", "bar"])
      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end
  end

  defp remove_device_tags_mutation(opts) do
    default_document = """
    mutation RemoveDeviceTags($id: ID!, $input: RemoveDeviceTagsInput!) {
      removeDeviceTags(id: $id, input: $input) {
        result {
          tags(first: 10, sort: [{ field: NAME, order: ASC }]) {
            count
            edges {
              node {
                name
              }
            }
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)
    {tags, opts} = Keyword.pop!(opts, :tags)

    input = %{"tags" => tags}

    variables = %{"id" => id, "input" => input}
    document = Keyword.get(opts, :document, default_document)
    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"removeDeviceTags" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{
             data: %{
               "removeDeviceTags" => %{
                 "result" => %{
                   "tags" => %{
                     "count" => count,
                     "edges" => edges
                   }
                 }
               }
             }
           } = result

    tags = Enum.map(edges, & &1["node"])

    assert length(tags) == count

    tags
  end

  defp non_existing_device_id(tenant) do
    fixture = device_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end
end
