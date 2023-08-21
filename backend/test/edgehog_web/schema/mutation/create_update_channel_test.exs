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

defmodule EdgehogWeb.Schema.Mutation.CreateUpdateChannelTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  describe "createUpdateChannel mutation" do
    test "creates update_channel with valid data", %{conn: conn, api_path: api_path} do
      target_group = device_group_fixture()

      response =
        create_update_channel_mutation(conn, api_path,
          name: "My Update Channel",
          handle: "my-update-channel",
          target_group_ids: [target_group.id]
        )

      update_channel = response["data"]["createUpdateChannel"]["updateChannel"]
      assert update_channel["name"] == "My Update Channel"
      assert update_channel["handle"] == "my-update-channel"
      assert [response_group] = update_channel["targetGroups"]
      assert response_group["name"] == target_group.name
      assert response_group["handle"] == target_group.handle
    end

    test "fails with invalid handle", %{conn: conn, api_path: api_path} do
      response = create_update_channel_mutation(conn, api_path, handle: "1nvalid Handle")

      assert response["data"]["createUpdateChannel"] == nil
      assert [%{"status_code" => 422, "message" => message}] = response["errors"]
      assert message =~ "Handle should start with"
    end

    test "fails when trying to use a non-existing target group", %{conn: conn, api_path: api_path} do
      response = create_update_channel_mutation(conn, api_path, target_group_ids: ["123456"])

      assert response["data"]["createUpdateChannel"] == nil
      assert [%{"status_code" => 422, "message" => message}] = response["errors"]
      assert message =~ "123456"
    end
  end

  @query """
  mutation CreateUpdateChannel($input: CreateUpdateChannelInput!) {
    createUpdateChannel(input: $input) {
      updateChannel {
        name
        handle
        targetGroups {
          name
          handle
        }
      }
    }
  }
  """
  defp create_update_channel_mutation(conn, api_path, opts) do
    target_group_ids =
      Keyword.get_lazy(opts, :target_group_ids, fn ->
        device_group_fixture()
        |> Map.get(:id)
        |> List.wrap()
      end)
      |> Enum.map(&Absinthe.Relay.Node.to_global_id(:device_group, &1, EdgehogWeb.Schema))

    input =
      opts
      |> Keyword.delete(:target_group_ids)
      |> Enum.into(%{
        name: unique_update_channel_name(),
        handle: unique_update_channel_handle(),
        target_group_ids: target_group_ids
      })

    variables = %{input: input}

    conn = post(conn, api_path, query: @query, variables: variables)

    json_response(conn, 200)
  end
end
