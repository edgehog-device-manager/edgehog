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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.NetworkSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.ContainersFixtures

  describe "Network subscriptions" do
    test "receive data on network creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      label = unique_network_label()
      network = network_fixture(tenant: tenant, label: label)

      assert_push "subscription:data", push
      assert_created "network", network_data, push

      assert network_data["id"] == AshGraphql.Resource.encode_relay_id(network)
      assert network_data["label"] == label
    end

    test "receive data on network destroy", %{socket: socket, tenant: tenant} do
      network = network_fixture(tenant: tenant)
      subscribe(socket)

      Ash.destroy!(network, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("network", network_id, push)

      assert network_id == AshGraphql.Resource.encode_relay_id(network)
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      network {
        created {
          id
          label
        }
        destroyed
      }
    }
    """

    query = Keyword.get(opts, :query, default_query)

    ref = push_doc(socket, query)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end
end
