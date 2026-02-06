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

defmodule EdgehogWeb.Schema.Subscriptions.Device.HardwareTypeSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.DevicesFixtures

  describe "HardwareType subscriptions" do
    test "receive data on hardware type creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      handle = unique_hardware_type_handle()
      name = unique_hardware_type_name()

      hardware_type =
        hardware_type_fixture(
          tenant: tenant,
          handle: handle,
          name: name,
          part_numbers: [unique_hardware_type_part_number()]
        )

      assert_push "subscription:data", push
      assert_created "hardwareType", data, push

      assert data["id"] == AshGraphql.Resource.encode_relay_id(hardware_type)
      assert data["handle"] == handle
      assert data["name"] == name
    end

    test "receive data on hardware type update", %{socket: socket, tenant: tenant} do
      hardware_type = hardware_type_fixture(tenant: tenant)
      subscribe(socket)

      new_name = unique_hardware_type_name()

      hardware_type =
        hardware_type
        |> Ash.Changeset.for_update(:update, %{name: new_name})
        |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push
      assert_updated "hardwareType", data, push

      assert data["id"] == AshGraphql.Resource.encode_relay_id(hardware_type)
      assert data["name"] == new_name
    end

    test "receive data on hardware type destroy", %{socket: socket, tenant: tenant} do
      hardware_type = hardware_type_fixture(tenant: tenant)
      subscribe(socket)

      Ash.destroy!(hardware_type, action: :destroy, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("hardwareType", destroyed_id, push)

      assert destroyed_id == AshGraphql.Resource.encode_relay_id(hardware_type)
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      hardwareType {
        created {
          id
          handle
          name
        }
        updated {
          id
          handle
          name
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
