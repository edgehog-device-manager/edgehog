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

defmodule EdgehogWeb.Schema.Subscriptions.DeviceGroup.DeviceGroupSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.GroupsFixtures

  describe "DeviceGroup subscription" do
    test "receive data on device group creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      device_group = device_group_fixture(tenant: tenant)

      assert_push "subscription:data", push

      assert_created "deviceGroup", device_group_data, push

      assert device_group_data["id"] == AshGraphql.Resource.encode_relay_id(device_group)
      assert device_group_data["name"] == device_group.name
      assert device_group_data["handle"] == device_group.handle
      assert device_group_data["selector"] == device_group.selector
    end

    test "receive data on device group update", %{socket: socket, tenant: tenant} do
      device_group = device_group_fixture(tenant: tenant)
      subscribe(socket)

      new_name = "new_name_#{System.unique_integer()}"

      device_group
      |> Ash.Changeset.for_update(:update, %{name: new_name})
      |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push
      assert_updated "deviceGroup", device_group_data, push

      assert device_group_data["id"] == AshGraphql.Resource.encode_relay_id(device_group)
      assert device_group_data["name"] == new_name
      assert device_group_data["handle"] == device_group.handle
      assert device_group_data["selector"] == device_group.selector
    end

    test "receive data on device group destroy", %{socket: socket, tenant: tenant} do
      device_group = device_group_fixture(tenant: tenant)
      subscribe(socket)

      Ash.destroy!(device_group, tenant: tenant)
      assert_push "subscription:data", push
      assert_destroyed("deviceGroup", device_group_id, push)

      assert device_group_id == AshGraphql.Resource.encode_relay_id(device_group)
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_sub_gql = """
    subscription {
      deviceGroup {
        created {
          id
          name
          handle
          selector
        }
        updated {
          id
          name
          handle
          selector
        }
        destroyed
      }
    }
    """

    sub_gql = Keyword.get(opts, :query, default_sub_gql)

    ref = push_doc(socket, sub_gql)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end
end
