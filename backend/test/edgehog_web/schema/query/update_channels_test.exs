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

defmodule EdgehogWeb.Schema.Query.UpdateChannelsTest do
  use EdgehogWeb.ConnCase

  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  describe "updateChannels query" do
    setup do
      {:ok, target_group: device_group_fixture()}
    end

    test "returns empty update channels", %{conn: conn, api_path: api_path} do
      response = update_channels_query(conn, api_path)
      assert response["data"]["updateChannels"] == []
    end

    test "returns update channels if present", %{
      conn: conn,
      api_path: api_path,
      target_group: target_group
    } do
      update_channel = update_channel_fixture(target_group_ids: [target_group.id])
      response = update_channels_query(conn, api_path)

      assert [response_channel] = response["data"]["updateChannels"]
      assert response_channel["handle"] == update_channel.handle
      assert response_channel["name"] == update_channel.name
      assert [response_group] = response_channel["targetGroups"]
      assert response_group["handle"] == target_group.handle
      assert response_group["name"] == target_group.name
    end
  end

  @query """
  query {
    updateChannels {
      handle
      name
      targetGroups {
        name
        handle
      }
    }
  }
  """
  defp update_channels_query(conn, api_path, opts \\ []) do
    query = Keyword.get(opts, :query, @query)
    conn = get(conn, api_path, query: query)

    json_response(conn, 200)
  end
end
