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

defmodule EdgehogWeb.Schema.Mutation.AddDeviceTagsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures

  @moduletag :ported_to_ash

  describe "addDeviceTags mutation" do
    setup %{tenant: tenant} do
      device = device_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(device)

      %{device: device, id: id}
    end

    test "successfully adds tags", %{tenant: tenant, id: id} do
      result = add_device_tags_mutation(tenant: tenant, id: id, tags: ["foo", "bar"])

      assert %{"tags" => tags} = extract_result!(result)
      assert length(tags) == 2
      tag_names = Enum.map(tags, &Map.fetch!(&1, "name"))
      assert "foo" in tag_names
      assert "bar" in tag_names
    end

    test "is idempotent and doesn't remove tags", %{tenant: tenant, device: device, id: id} do
      device
      |> Ash.Changeset.for_update(:add_tags, %{tags: ["foo", "bar"]})
      |> Ash.update!()

      result =
        add_device_tags_mutation(tenant: tenant, id: id, tags: ["foo", "baz"])

      assert %{"tags" => tags} = extract_result!(result)
      assert length(tags) == 3
      tag_names = Enum.map(tags, &Map.fetch!(&1, "name"))
      assert "foo" in tag_names
      assert "bar" in tag_names
      assert "baz" in tag_names
    end

    test "fails with empty tags", %{tenant: tenant, id: id} do
      result = add_device_tags_mutation(tenant: tenant, id: id, tags: [])
      assert %{fields: [:tags], message: "must have 1 or more items"} = extract_error!(result)
    end

    test "fails with non-existing id", %{tenant: tenant} do
      id = non_existing_device_id(tenant)
      result = add_device_tags_mutation(tenant: tenant, id: id, tags: ["foo", "bar"])
      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end
  end

  defp add_device_tags_mutation(opts) do
    default_document = """
    mutation AddDeviceTags($id: ID!, $input: AddDeviceTagsInput!) {
      addDeviceTags(id: $id, input: $input) {
        result {
          tags {
            name
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
             data: %{"addDeviceTags" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{
             data: %{
               "addDeviceTags" => %{
                 "result" => device
               }
             }
           } = result

    assert device != nil

    device
  end

  defp non_existing_device_id(tenant) do
    fixture = device_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end
end
