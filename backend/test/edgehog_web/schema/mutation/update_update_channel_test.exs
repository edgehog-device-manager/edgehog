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

defmodule EdgehogWeb.Schema.Mutation.UpdateUpdateChannelTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  describe "updateUpdateChannel mutation" do
    setup do
      {:ok, update_channel: update_channel_fixture()}
    end

    test "updates update channel with valid data", %{
      conn: conn,
      api_path: api_path,
      update_channel: update_channel
    } do
      target_group = device_group_fixture()

      response =
        update_update_channel_mutation(conn, api_path,
          update_channel_id: update_channel.id,
          name: "Updated name",
          handle: "updated-handle",
          target_group_ids: [target_group.id]
        )

      update_channel = response["data"]["updateUpdateChannel"]["updateChannel"]
      assert update_channel["name"] == "Updated name"
      assert update_channel["handle"] == "updated-handle"
      assert [response_group] = update_channel["targetGroups"]
      assert response_group["name"] == target_group.name
      assert response_group["handle"] == target_group.handle
    end

    test "fails with invalid handle", %{
      conn: conn,
      api_path: api_path,
      update_channel: update_channel
    } do
      response =
        update_update_channel_mutation(conn, api_path,
          update_channel_id: update_channel.id,
          handle: "1nvalid Handle"
        )

      assert response["data"]["updateUpdateChannel"] == nil
      assert [%{"status_code" => 422, "message" => message}] = response["errors"]
      assert message =~ "Handle should start with"
    end

    test "fails when trying to use a non-existing target group id", %{
      conn: conn,
      api_path: api_path,
      update_channel: update_channel
    } do
      response =
        update_update_channel_mutation(conn, api_path,
          update_channel_id: update_channel.id,
          target_group_ids: ["123456"]
        )

      assert response["data"]["updateUpdateChannel"] == nil
      assert %{"errors" => [%{"status_code" => 422, "message" => message}]} = response
      assert message =~ "123456"
    end
  end

  @query """
  mutation UpdateUpdateChannel($input: UpdateUpdateChannelInput!) {
    updateUpdateChannel(input: $input) {
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
  defp update_update_channel_mutation(conn, api_path, opts) do
    update_channel_id =
      opts
      |> Keyword.fetch!(:update_channel_id)
      |> then(&Absinthe.Relay.Node.to_global_id(:update_channel, &1, EdgehogWeb.Schema))

    input =
      opts
      |> Keyword.update(:target_group_ids, nil, fn ids ->
        ids
        |> Enum.map(&Absinthe.Relay.Node.to_global_id(:device_group, &1, EdgehogWeb.Schema))
      end)
      |> Keyword.delete(:update_channel_id)
      |> Enum.into(%{
        update_channel_id: update_channel_id
      })

    variables = %{input: input}

    conn = post(conn, api_path, query: @query, variables: variables)

    json_response(conn, 200)
  end
end
