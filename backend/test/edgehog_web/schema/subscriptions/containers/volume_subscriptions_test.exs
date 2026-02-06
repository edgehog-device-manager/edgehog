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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.VolumeSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.ContainersFixtures

  describe "Volume subscriptions" do
    test "receive data on volume creation", %{socket: socket, tenant: tenant} do
      subscribe(socket, query: volume_created_query())

      label = unique_volume_label()
      volume = volume_fixture(tenant: tenant, label: label)

      assert_push "subscription:data", push
      assert_created "volume", volume_data, push

      assert volume_data["id"] == AshGraphql.Resource.encode_relay_id(volume)
      assert volume_data["label"] == label
    end

    test "receive data on volume destroy", %{socket: socket, tenant: tenant} do
      volume = volume_fixture(tenant: tenant)
      subscribe(socket, query: volume_destroyed_query())

      Ash.destroy!(volume, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("volume", volume_id, push)

      assert volume_id == AshGraphql.Resource.encode_relay_id(volume)
    end
  end

  defp subscribe(socket, opts) do
    query = Keyword.fetch!(opts, :query)

    ref = push_doc(socket, query)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end

  defp volume_created_query do
    """
    subscription {
      volume {
        created {
          id
          label
        }
      }
    }
    """
  end

  defp volume_destroyed_query do
    """
    subscription {
      volume {
        destroyed
      }
    }
    """
  end
end
