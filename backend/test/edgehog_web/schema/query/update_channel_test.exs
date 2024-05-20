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

defmodule EdgehogWeb.Schema.Query.UpdateChannelTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Edgehog.UpdateCampaigns.UpdateChannel

  @moduletag :ported_to_ash

  describe "updateChannel query" do
    setup %{tenant: tenant} do
      {:ok, target_group: device_group_fixture(tenant: tenant)}
    end

    test "returns update channel if present", %{tenant: tenant, target_group: target_group} do
      update_channel = update_channel_fixture(target_group_ids: [target_group.id], tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(update_channel)

      update_channel_data = update_channel_query(tenant: tenant, id: id) |> extract_result!()

      assert update_channel_data["handle"] == update_channel.handle
      assert update_channel_data["name"] == update_channel.name
      assert [response_group] = update_channel_data["targetGroups"]
      assert response_group["handle"] == target_group.handle
      assert response_group["name"] == target_group.name
    end

    test "returns nil if non existing", %{tenant: tenant} do
      id = non_existing_update_channel_id(tenant)
      assert %{data: %{"updateChannel" => nil}} == update_channel_query(tenant: tenant, id: id)
    end
  end

  defp update_channel_query(opts) do
    default_document = """
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

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables = %{"id" => id}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateChannel" => update_channel
             }
           } = result

    refute Map.get(result, :errors)

    assert update_channel != nil

    update_channel
  end

  defp non_existing_update_channel_id(tenant) do
    fixture = update_channel_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture)

    id
  end
end
