#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Subscriptions.Campaign.ChannelSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.CampaignsFixtures

  describe "Channels subscription" do
    test "receive data on channel creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      channel = channel_fixture(tenant: tenant)

      assert_push "subscription:data", push

      assert_created("channels", channel_data, push)

      assert channel_data["id"] == AshGraphql.Resource.encode_relay_id(channel)
    end

    test "receive data on channel update", %{socket: socket, tenant: tenant} do
      channel = channel_fixture(tenant: tenant)

      channel_updated_query = """
      subscription {
        channels {
          updated {
            id
            name
          }
        }
      }
      """

      subscribe(socket, query: channel_updated_query)

      channel
      |> Ash.Changeset.for_update(:update, %{name: "new_name"}, tenant: tenant)
      |> Ash.update!()

      assert_push "subscription:data", push

      assert_updated("channels", channel_data, push)

      assert channel_data["id"] == AshGraphql.Resource.encode_relay_id(channel)
      assert channel_data["name"] == "new_name"
    end

    test "receive data on channel destroy", %{socket: socket, tenant: tenant} do
      channel = channel_fixture(tenant: tenant)

      channel_deleted_query = """
      subscription {
        channels {
          destroyed
        }
      }
      """

      subscribe(socket, query: channel_deleted_query)

      Ash.destroy!(channel)

      assert_push "subscription:data", push

      assert_destroyed("channels", channel_data, push)

      assert channel_data == AshGraphql.Resource.encode_relay_id(channel)
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      channels{
        created {
          id
        }
        updated {
          id
        }
      }
    }
    """

    query = Keyword.get(opts, :query, default_query)

    ref = push_doc(socket, query)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end
end
