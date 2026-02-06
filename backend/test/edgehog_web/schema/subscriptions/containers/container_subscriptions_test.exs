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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.ContainerSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.ContainersFixtures

  describe "Container subscriptions" do
    test "receive data on container creation", %{socket: socket, tenant: tenant} do
      subscribe(socket, query: container_created_query())

      hostname = unique_container_hostname()
      container = container_fixture(tenant: tenant, hostname: hostname)

      assert_push "subscription:data", push
      assert_created "container", container_data, push

      assert container_data["id"] == AshGraphql.Resource.encode_relay_id(container)
      assert container_data["hostname"] == hostname
    end

    test "receive data on container update", %{socket: socket, tenant: tenant} do
      container = container_fixture(tenant: tenant)
      subscribe(socket, query: container_updated_query())

      new_hostname = unique_container_hostname()

      container =
        container
        |> Ash.Changeset.for_update(:update, %{hostname: new_hostname})
        |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push
      assert_updated "container", container_data, push

      assert container_data["id"] == AshGraphql.Resource.encode_relay_id(container)
      assert container_data["hostname"] == new_hostname
    end

    test "receive data on container destroy", %{socket: socket, tenant: tenant} do
      container = container_fixture(tenant: tenant)
      subscribe(socket, query: container_destroyed_query())

      Ash.destroy!(container, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("container", container_id, push)

      assert container_id == AshGraphql.Resource.encode_relay_id(container)
    end
  end

  defp subscribe(socket, opts) do
    query = Keyword.fetch!(opts, :query)

    ref = push_doc(socket, query)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end

  defp container_created_query do
    """
    subscription {
      container {
        created {
          id
          hostname
        }
      }
    }
    """
  end

  defp container_updated_query do
    """
    subscription {
      container {
        updated {
          id
          hostname
        }
      }
    }
    """
  end

  defp container_destroyed_query do
    """
    subscription {
      container {
        destroyed
      }
    }
    """
  end
end
