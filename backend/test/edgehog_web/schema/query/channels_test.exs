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

defmodule EdgehogWeb.Schema.Query.ChannelsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.GroupsFixtures

  describe "channels query" do
    setup %{tenant: tenant} do
      {:ok, target_group: device_group_fixture(tenant: tenant)}
    end

    test "returns empty update channels", %{tenant: tenant} do
      assert [] == [tenant: tenant] |> channels_query() |> extract_result!()
    end

    test "returns update channels if present", %{tenant: tenant, target_group: target_group} do
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)

      [channel_data] =
        [tenant: tenant] |> channels_query() |> extract_result!() |> extract_nodes!()

      assert channel_data["id"] == AshGraphql.Resource.encode_relay_id(channel)
      assert channel_data["handle"] == channel.handle
      assert channel_data["name"] == channel.name

      assert [target_group_data] =
               extract_nodes!(channel_data["targetGroups"]["edges"])

      assert target_group_data["id"] == AshGraphql.Resource.encode_relay_id(target_group)
      assert target_group_data["handle"] == target_group.handle
      assert target_group_data["name"] == target_group.name
    end
  end

  defp channels_query(opts) do
    default_document = """
    query {
      channels {
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
               "channels" => %{
                 "edges" => channels
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert channels != nil

    channels
  end

  defp extract_nodes!(data) do
    Enum.map(data, &Map.fetch!(&1, "node"))
  end
end
