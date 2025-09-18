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

defmodule EdgehogWeb.Schema.Mutation.CreateChannelTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.GroupsFixtures

  describe "createChannel mutation" do
    test "creates channel with valid data", %{tenant: tenant} do
      target_group = device_group_fixture(tenant: tenant)
      assert target_group.channel_id == nil

      target_group_id = AshGraphql.Resource.encode_relay_id(target_group)

      channel_data =
        [
          name: "My Channel",
          handle: "my-channel",
          target_group_ids: [target_group_id],
          tenant: tenant
        ]
        |> create_channel_mutation()
        |> extract_result!()

      assert channel_data["name"] == "My Channel"
      assert channel_data["handle"] == "my-channel"

      assert [target_group_data] =
               extract_nodes!(channel_data["targetGroups"]["edges"])

      assert target_group_data["id"] == target_group_id
      assert target_group_data["name"] == target_group.name
      assert target_group_data["handle"] == target_group.handle
    end

    test "creates channel with nil target_group_ids", %{tenant: tenant} do
      name = unique_channel_name()
      handle = unique_channel_handle()

      result =
        [target_group_ids: nil, tenant: tenant, name: name, handle: handle]
        |> create_channel_mutation()
        |> extract_result!()

      assert result["name"] == name
      assert result["handle"] == handle
      assert result["targetGroups"]["edges"] == []
    end

    test "creates channel with empty target_group_ids", %{tenant: tenant} do
      name = unique_channel_name()
      handle = unique_channel_handle()

      result =
        [target_group_ids: [], tenant: tenant, name: name, handle: handle]
        |> create_channel_mutation()
        |> extract_result!()

      assert result["name"] == name
      assert result["handle"] == handle
      assert result["targetGroups"]["edges"] == []
    end

    test "fails with missing name", %{tenant: tenant} do
      error =
        [name: nil, tenant: tenant]
        |> create_channel_mutation()
        |> extract_error!()

      assert %{message: message} = error
      assert message =~ ~s<In field "name": Expected type "String!", found null.>
    end

    test "fails with empty name", %{tenant: tenant} do
      error =
        [name: "", tenant: tenant]
        |> create_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["createChannel"],
               fields: [:name],
               message: "is required",
               code: "required"
             } = error
    end

    test "fails with non-unique name", %{tenant: tenant} do
      _ = channel_fixture(tenant: tenant, name: "existing-name")

      error =
        [name: "existing-name", tenant: tenant]
        |> create_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["createChannel"],
               fields: [:name],
               message: "has already been taken",
               code: "invalid_attribute"
             } = error
    end

    test "fails with missing handle", %{tenant: tenant} do
      error =
        [handle: nil, tenant: tenant]
        |> create_channel_mutation()
        |> extract_error!()

      assert %{message: message} = error
      assert message =~ ~s<In field "handle": Expected type "String!", found null.>
    end

    test "fails with empty handle", %{tenant: tenant} do
      error =
        [handle: "", tenant: tenant]
        |> create_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["createChannel"],
               fields: [:handle],
               message: "is required",
               code: "required"
             } = error
    end

    test "fails with invalid handle", %{tenant: tenant} do
      error =
        [handle: "1nvalid Handle", tenant: tenant]
        |> create_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["createChannel"],
               fields: [:handle],
               message: "should only contain lower case ASCII letters (from a to z), digits and -",
               code: "invalid_attribute"
             } = error
    end

    test "fails with non-unique handle", %{tenant: tenant} do
      _ = channel_fixture(tenant: tenant, handle: "existing-handle")

      error =
        [handle: "existing-handle", tenant: tenant]
        |> create_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["createChannel"],
               fields: [:handle],
               message: "has already been taken",
               code: "invalid_attribute"
             } = error
    end

    test "fails when trying to use a non-existing target group", %{tenant: tenant} do
      target_group_id = non_existing_device_group_id(tenant)

      error =
        [target_group_ids: [target_group_id], tenant: tenant]
        |> create_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["createChannel"],
               fields: [:target_group_ids],
               message: "One or more target groups could not be found",
               code: "not_found"
             } = error
    end

    test "fails when trying to use already assigned target groups", %{tenant: tenant} do
      target_group = device_group_fixture(tenant: tenant)

      _ =
        channel_fixture(
          tenant: tenant,
          target_group_ids: [target_group.id]
        )

      target_group_id = AshGraphql.Resource.encode_relay_id(target_group)

      error =
        [target_group_ids: [target_group_id], tenant: tenant]
        |> create_channel_mutation()
        |> extract_error!()

      assert %{
               path: ["createChannel"],
               fields: [:channel_id],
               message: "The channel is already set for the device group " <> name,
               code: "invalid_attribute"
             } = error

      assert name == ~s["#{target_group.name}"]
    end
  end

  defp create_channel_mutation(opts) do
    default_document = """
    mutation CreateChannel($input: CreateChannelInput!) {
      createChannel(input: $input) {
        result {
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

    {target_group_ids, opts} =
      Keyword.pop_lazy(opts, :target_group_ids, fn ->
        group = device_group_fixture(tenant: tenant)
        [AshGraphql.Resource.encode_relay_id(group)]
      end)

    {name, opts} = Keyword.pop_lazy(opts, :name, fn -> unique_channel_name() end)

    {handle, opts} = Keyword.pop_lazy(opts, :handle, fn -> unique_channel_handle() end)

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
    assert is_nil(result[:data]["createChannel"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createChannel" => %{
                 "result" => channel
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert channel != nil

    channel
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
