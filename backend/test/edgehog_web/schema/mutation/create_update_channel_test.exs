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

defmodule EdgehogWeb.Schema.Mutation.CreateUpdateChannelTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  @moduletag :ported_to_ash

  describe "createUpdateChannel mutation" do
    test "creates update_channel with valid data", %{tenant: tenant} do
      target_group = device_group_fixture(tenant: tenant)

      target_group_id = AshGraphql.Resource.encode_relay_id(target_group)

      update_channel_data =
        create_update_channel_mutation(
          name: "My Update Channel",
          handle: "my-update-channel",
          target_group_ids: [target_group_id],
          tenant: tenant
        )
        |> extract_result!()

      assert update_channel_data["name"] == "My Update Channel"
      assert update_channel_data["handle"] == "my-update-channel"
      assert [target_group_data] = update_channel_data["targetGroups"]
      assert target_group_data["id"] == target_group_id
      assert target_group_data["name"] == target_group.name
      assert target_group_data["handle"] == target_group.handle
    end

    test "fails with missing name", %{tenant: tenant} do
      error =
        create_update_channel_mutation(name: nil, tenant: tenant)
        |> extract_error!()

      assert %{message: message} = error
      assert message =~ ~s<In field "name": Expected type "String!", found null.>
    end

    test "fails with empty name", %{tenant: tenant} do
      error =
        create_update_channel_mutation(name: "", tenant: tenant)
        |> extract_error!()

      assert %{
               path: ["createUpdateChannel"],
               fields: [:name],
               message: "is required",
               code: "required"
             } = error
    end

    test "fails with non-unique name", %{tenant: tenant} do
      _ = update_channel_fixture(tenant: tenant, name: "existing-name")

      error =
        create_update_channel_mutation(name: "existing-name", tenant: tenant)
        |> extract_error!()

      assert %{
               path: ["createUpdateChannel"],
               fields: [:name],
               message: "has already been taken",
               code: "invalid_attribute"
             } = error
    end

    test "fails with missing handle", %{tenant: tenant} do
      error =
        create_update_channel_mutation(handle: nil, tenant: tenant)
        |> extract_error!()

      assert %{message: message} = error
      assert message =~ ~s<In field "handle": Expected type "String!", found null.>
    end

    test "fails with empty handle", %{tenant: tenant} do
      error =
        create_update_channel_mutation(handle: "", tenant: tenant)
        |> extract_error!()

      assert %{
               path: ["createUpdateChannel"],
               fields: [:handle],
               message: "is required",
               code: "required"
             } = error
    end

    test "fails with invalid handle", %{tenant: tenant} do
      error =
        create_update_channel_mutation(handle: "1nvalid Handle", tenant: tenant)
        |> extract_error!()

      assert %{
               path: ["createUpdateChannel"],
               fields: [:handle],
               message:
                 "should only contain lower case ASCII letters (from a to z), digits and -",
               code: "invalid_attribute"
             } = error
    end

    test "fails with non-unique handle", %{tenant: tenant} do
      _ = update_channel_fixture(tenant: tenant, handle: "existing-handle")

      error =
        create_update_channel_mutation(handle: "existing-handle", tenant: tenant)
        |> extract_error!()

      assert %{
               path: ["createUpdateChannel"],
               fields: [:handle],
               message: "has already been taken",
               code: "invalid_attribute"
             } = error
    end

    test "fails with missing target_group_ids", %{tenant: tenant} do
      error =
        create_update_channel_mutation(target_group_ids: nil, tenant: tenant)
        |> extract_error!()

      assert %{message: message} = error
      assert message =~ ~s<In field "targetGroupIds": Expected type "[ID!]!", found null.>
    end

    test "fails with empty target_group_ids", %{tenant: tenant} do
      error =
        create_update_channel_mutation(target_group_ids: [], tenant: tenant)
        |> extract_error!()

      assert %{
               path: ["createUpdateChannel"],
               fields: [:target_group_ids],
               message: "must have 1 or more items",
               code: "invalid_argument"
             } = error
    end

    test "fails when trying to use a non-existing target group", %{tenant: tenant} do
      target_group_id = non_existing_device_group_id(tenant)

      error =
        create_update_channel_mutation(target_group_ids: [target_group_id], tenant: tenant)
        |> extract_error!()

      assert %{
               path: ["createUpdateChannel"],
               fields: [:target_group_ids],
               message:
                 "some target groups were not found or are already associated with an update channel",
               code: "invalid_argument"
             } = error
    end

    test "fails when trying to use already assigned target groups", %{tenant: tenant} do
      target_group = device_group_fixture(tenant: tenant)
      _ = update_channel_fixture(tenant: tenant, target_group_ids: [target_group.id])

      target_group_id = AshGraphql.Resource.encode_relay_id(target_group)

      error =
        create_update_channel_mutation(target_group_ids: [target_group_id], tenant: tenant)
        |> extract_error!()

      assert %{
               path: ["createUpdateChannel"],
               fields: [:target_group_ids],
               message:
                 "some target groups were not found or are already associated with an update channel",
               code: "invalid_argument"
             } = error
    end
  end

  defp create_update_channel_mutation(opts) do
    default_document = """
    mutation CreateUpdateChannel($input: CreateUpdateChannelInput!) {
      createUpdateChannel(input: $input) {
        result {
          name
          handle
          targetGroups {
            id
            name
            handle
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {target_group_ids, opts} =
      Keyword.pop_lazy(opts, :target_group_ids, fn ->
        group = device_group_fixture(tenant: tenant)
        [AshGraphql.Resource.encode_relay_id(group)]
      end)

    {name, opts} = Keyword.pop_lazy(opts, :name, fn -> unique_update_channel_name() end)

    {handle, opts} = Keyword.pop_lazy(opts, :handle, fn -> unique_update_channel_handle() end)

    input = %{
      "name" => name,
      "handle" => handle,
      "targetGroupIds" => target_group_ids
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["createUpdateChannel"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createUpdateChannel" => %{
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
end
