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

defmodule EdgehogWeb.Schema.Subscriptions.Labeling.TagsSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.LabelingFixtures

  describe "Tag subscription" do
    test "receive data on tag creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      tag = tag_fixture(tenant: tenant)

      assert_push "subscription:data", push

      assert_created "tag", tag_data, push

      assert tag_data["id"] == AshGraphql.Resource.encode_relay_id(tag)
      assert tag_data["name"] == tag.name
    end

    defp subscribe(socket, opts \\ []) do
      default_sub_gql = """
      subscription Tag {
      tag {
          created {
              id
              name
          }
      }
      }
      """

      sub_gql = Keyword.get(opts, :query, default_sub_gql)

      ref = push_doc(socket, sub_gql)
      assert_reply ref, :ok, %{subscriptionId: subscription_id}

      subscription_id
    end
  end
end
