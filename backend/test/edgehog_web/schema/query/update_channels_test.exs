#
# This file is part of Edgehog.
#
# Copyright 2023 - 2025 SECO Mind Srl
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
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  describe "updateChannels query" do
    setup %{tenant: tenant} do
      {:ok, target_group: device_group_fixture(tenant: tenant)}
    end

    test "returns empty update channels", %{tenant: tenant} do
      assert [] == [tenant: tenant] |> update_channels_query() |> extract_result!()
    end

    test "returns update channels if present", %{tenant: tenant, target_group: target_group} do
      update_channel = update_channel_fixture(target_group_ids: [target_group.id], tenant: tenant)

      [update_channel_data] =
        [tenant: tenant] |> update_channels_query() |> extract_result!() |> extract_nodes!()

      assert update_channel_data["id"] == AshGraphql.Resource.encode_relay_id(update_channel)
      assert update_channel_data["handle"] == update_channel.handle
      assert update_channel_data["name"] == update_channel.name

      assert [target_group_data] =
               extract_nodes!(update_channel_data["targetGroups"]["edges"])

      assert target_group_data["id"] == AshGraphql.Resource.encode_relay_id(target_group)
      assert target_group_data["handle"] == target_group.handle
      assert target_group_data["name"] == target_group.name
    end
  end

  defp update_channels_query(opts) do
    default_document = """
    query {
      updateChannels {
        edges {
          node {
            id
            handle
            name
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
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateChannels" => %{
                 "edges" => update_channels
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert update_channels != nil

    update_channels
  end

  defp extract_nodes!(data) do
    Enum.map(data, &Map.fetch!(&1, "node"))
  end
end
