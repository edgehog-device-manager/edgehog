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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.ReleaseSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.ContainersFixtures

  describe "Release subscriptions" do
    test "receive data on release creation", %{socket: socket, tenant: tenant} do
      subscribe(socket, query: release_created_query())

      version = unique_release_version()
      release = release_fixture(tenant: tenant, version: version)

      assert_push "subscription:data", push
      assert_created "release", release_data, push

      assert release_data["id"] == AshGraphql.Resource.encode_relay_id(release)
      assert release_data["version"] == version
    end

    test "receive data on release destroy", %{socket: socket, tenant: tenant} do
      release = release_fixture(tenant: tenant)
      subscribe(socket, query: release_destroyed_query())

      Ash.destroy!(release, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("release", release_id, push)

      assert release_id == AshGraphql.Resource.encode_relay_id(release)
    end
  end

  defp subscribe(socket, opts) do
    query = Keyword.fetch!(opts, :query)

    ref = push_doc(socket, query)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end

  defp release_created_query do
    """
    subscription {
      release {
        created {
          id
          version
        }
      }
    }
    """
  end

  defp release_destroyed_query do
    """
    subscription {
      release {
        destroyed
      }
    }
    """
  end
end
