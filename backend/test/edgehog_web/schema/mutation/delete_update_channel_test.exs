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

defmodule EdgehogWeb.Schema.Mutation.DeleteUpdateChannelTest do
  use EdgehogWeb.ConnCase, async: true

  alias Edgehog.UpdateCampaigns
  import Edgehog.UpdateCampaignsFixtures

  describe "deleteUpdateChannel mutation" do
    setup do
      {:ok, update_channel: update_channel_fixture()}
    end

    test "deletes existing update channel", %{
      conn: conn,
      api_path: api_path,
      update_channel: update_channel
    } do
      response = delete_update_channel_mutation(conn, api_path, update_channel.id)

      assert response["data"]["deleteUpdateChannel"]["updateChannel"]["handle"] ==
               update_channel.handle

      assert UpdateCampaigns.fetch_update_channel(update_channel.id) == {:error, :not_found}
    end

    test "fails with non-existing update channel", %{
      conn: conn,
      api_path: api_path
    } do
      response = delete_update_channel_mutation(conn, api_path, "123456")
      assert %{"errors" => [%{"status_code" => 404, "code" => "not_found"}]} = response
    end
  end

  @query """
  mutation DeleteUpdateChannel($input: DeleteUpdateChannelInput!) {
    deleteUpdateChannel(input: $input) {
      updateChannel {
        handle
      }
    }
  }
  """
  defp delete_update_channel_mutation(conn, api_path, db_id) do
    update_channel_id =
      Absinthe.Relay.Node.to_global_id(:update_channel, db_id, EdgehogWeb.Schema)

    variables = %{input: %{update_channel_id: update_channel_id}}

    conn = post(conn, api_path, query: @query, variables: variables)

    json_response(conn, 200)
  end
end
