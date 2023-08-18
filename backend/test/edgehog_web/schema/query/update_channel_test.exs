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

defmodule EdgehogWeb.Schema.Query.UpdateChannelTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Edgehog.UpdateCampaigns.UpdateChannel

  describe "updateChannel query" do
    setup do
      {:ok, target_group: device_group_fixture()}
    end

    test "returns update channel if present", %{
      conn: conn,
      api_path: api_path,
      target_group: target_group
    } do
      update_channel = update_channel_fixture(target_group_ids: [target_group.id])
      response = update_channel_query(conn, api_path, update_channel)

      assert response["data"]["updateChannel"]["handle"] == update_channel.handle
      assert response["data"]["updateChannel"]["name"] == update_channel.name
      assert [response_group] = response["data"]["updateChannel"]["targetGroups"]
      assert response_group["handle"] == target_group.handle
      assert response_group["name"] == target_group.name
    end

    test "returns not found if non existing", %{conn: conn, api_path: api_path} do
      response = update_channel_query(conn, api_path, 1_234_567)
      assert response["data"]["updateChannel"] == nil
      assert [%{"code" => "not_found", "status_code" => 404}] = response["errors"]
    end
  end

  @query """
  query ($id: ID!) {
    updateChannel(id: $id) {
      handle
      name
      targetGroups {
        name
        handle
      }
    }
  }
  """
  defp update_channel_query(conn, api_path, target, opts \\ [])

  defp update_channel_query(conn, api_path, %UpdateChannel{} = target_group, opts) do
    update_channel_query(conn, api_path, target_group.id, opts)
  end

  defp update_channel_query(conn, api_path, id, opts) do
    id = Absinthe.Relay.Node.to_global_id(:update_channel, id, EdgehogWeb.Schema)

    variables = %{id: id}
    query = Keyword.get(opts, :query, @query)
    conn = get(conn, api_path, query: query, variables: variables)

    json_response(conn, 200)
  end
end
