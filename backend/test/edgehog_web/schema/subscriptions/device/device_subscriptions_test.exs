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

defmodule EdgehogWeb.Schema.Subscriptions.Device.DeviceSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.DevicesFixtures

  describe "Device subscription" do
    test "receive data on device creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      device = device_fixture(tenant: tenant)

      assert_push "subscription:data", push

      assert_created "deviceChanged", device_data, push

      assert device_data["id"] == AshGraphql.Resource.encode_relay_id(device)
      assert device_data["name"] == device.name
    end

    test "receive data on device_update", %{socket: socket, tenant: tenant} do
      device = device_fixture(tenant: tenant)
      subscribe(socket)

      new_name = "new_name_#{System.unique_integer()}"

      device
      |> Ash.Changeset.for_update(:update, %{name: new_name})
      |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push
      assert_updated "deviceChanged", device_data, push

      assert device_data["id"] == AshGraphql.Resource.encode_relay_id(device)
      assert device_data["name"] == new_name
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_sub_gql = """
    subscription {
      deviceChanged {
        created {
          id
          name
        }
        updated {
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
