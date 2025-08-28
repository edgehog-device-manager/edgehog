#
# This file is part of Edgehog.
#
# Copyright 2023-2025 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.UpdateUpdateChannelTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  describe "updateUpdateChannel mutation" do
    setup %{tenant: tenant} do
      update_channel = update_channel_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(update_channel)

      {:ok, update_channel: update_channel, id: id}
    end

    test "updates update channel with valid data", %{tenant: tenant, id: id} do
      target_group = device_group_fixture(tenant: tenant)
      target_group_id = AshGraphql.Resource.encode_relay_id(target_group)

      update_channel_data =
        [
          id: id,
          name: "Updated name",
          handle: "updated-handle",
          target_group_ids: [target_group_id],
          tenant: tenant
        ]
        |> update_update_channel_mutation()
        |> extract_result!()

      assert update_channel_data["id"] == id
      assert update_channel_data["name"] == "Updated name"
      assert update_channel_data["handle"] == "updated-handle"

      assert [target_group_data] =
               extract_nodes!(update_channel_data["targetGroups"]["edges"])

      assert target_group_data["id"] == target_group_id
      assert target_group_data["name"] == target_group.name
      assert target_group_data["handle"] == target_group.handle
    end

    test "fails with empty name", %{tenant: tenant, id: id} do
      error =
        [id: id, name: "", tenant: tenant]
        |> update_update_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["updateUpdateChannel"],
               fields: [:name],
               code: "required",
               message: "is required"
             } = error
    end

    test "fails with non-unique name", %{tenant: tenant, id: id} do
      _ = update_channel_fixture(tenant: tenant, name: "existing-name")

      error =
        [id: id, name: "existing-name", tenant: tenant]
        |> update_update_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["updateUpdateChannel"],
               fields: [:name],
               code: "invalid_attribute",
               message: "has already been taken"
             } = error
    end

    test "fails with empty handle", %{tenant: tenant, id: id} do
      error =
        [id: id, handle: "", tenant: tenant]
        |> update_update_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["updateUpdateChannel"],
               fields: [:handle],
               code: "required",
               message: "is required"
             } = error
    end

    test "fails with invalid handle", %{tenant: tenant, id: id} do
      error =
        [id: id, handle: "1nvalid Handle", tenant: tenant]
        |> update_update_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["updateUpdateChannel"],
               fields: [:handle],
               code: "invalid_attribute",
               message: "should only contain lower case ASCII letters (from a to z), digits and -"
             } = error
    end

    test "fails with non-unique handle", %{tenant: tenant, id: id} do
      _ = update_channel_fixture(tenant: tenant, handle: "existing-handle")

      error =
        [id: id, handle: "existing-handle", tenant: tenant]
        |> update_update_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["updateUpdateChannel"],
               fields: [:handle],
               code: "invalid_attribute",
               message: "has already been taken"
             } = error
    end

    test "updates update_channel with empty target_group_ids", %{tenant: tenant, id: id} do
      result =
        [id: id, target_group_ids: [], tenant: tenant]
        |> update_update_channel_mutation()
        |> extract_result!()

      assert result["id"] == id
    end

    test "fails when trying to use a non-existing target group id", %{tenant: tenant, id: id} do
      target_group_id = non_existing_device_group_id(tenant)

      error =
        [id: id, target_group_ids: [target_group_id], tenant: tenant]
        |> update_update_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["updateUpdateChannel"],
               fields: [:target_group_ids],
               code: "not_found",
               message: "One or more target groups could not be found"
             } = error
    end

    test "fails when trying to use already assigned target groups", %{tenant: tenant, id: id} do
      target_group = device_group_fixture(tenant: tenant)

      _ =
        update_channel_fixture(tenant: tenant, target_group_ids: [target_group.id])

      target_group_id = AshGraphql.Resource.encode_relay_id(target_group)

      error =
        [id: id, target_group_ids: [target_group_id], tenant: tenant]
        |> update_update_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["updateUpdateChannel"],
               fields: [:update_channel_id],
               code: "invalid_attribute",
               message: "The update channel is already set for the device group " <> name
             } = error

      assert name == ~s["#{target_group.name}"]
    end
  end

  defp update_update_channel_mutation(opts) do
    default_document = """
    mutation UpdateUpdateChannel($id: ID!, $input: UpdateUpdateChannelInput!) {
      updateUpdateChannel(id: $id, input: $input) {
        result {
          id
          name
          handle
          targetGroups {
            edges {
              node {
                id
                name
                handle
              }
            }
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    input =
      %{
        "handle" => opts[:handle],
        "name" => opts[:name],
        "targetGroupIds" => opts[:target_group_ids]
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Map.new()

    variables = %{"id" => id, "input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["updateUpdateChannel"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateUpdateChannel" => %{
                 "result" => update_channel
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert update_channel != nil

    update_channel
  end

  defp non_existing_device_group_id(tenant) do
    fixture = device_group_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end

  defp extract_nodes!(data) do
    Enum.map(data, &Map.fetch!(&1, "node"))
  end
end
