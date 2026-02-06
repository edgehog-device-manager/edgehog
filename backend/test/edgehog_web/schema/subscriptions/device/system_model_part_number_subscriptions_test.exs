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

defmodule EdgehogWeb.Schema.Subscriptions.Device.SystemModelPartNumberSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.DevicesFixtures

  describe "SystemModelPartNumber subscriptions" do
    test "receive data on system model part number creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      part_number = unique_system_model_part_number()

      part_number_record =
        system_model_part_number_fixture(tenant: tenant, part_number: part_number)

      assert_push "subscription:data", push
      assert_created "systemModelPartNumber", data, push

      assert data["id"] == AshGraphql.Resource.encode_relay_id(part_number_record)
      assert data["partNumber"] == part_number
    end

    test "receive data on system model part number update", %{socket: socket, tenant: tenant} do
      part_number_record = system_model_part_number_fixture(tenant: tenant)
      subscribe(socket)

      new_part_number = unique_system_model_part_number()

      part_number_record =
        part_number_record
        |> Ash.Changeset.for_update(:update, %{part_number: new_part_number})
        |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push
      assert_updated "systemModelPartNumber", data, push

      assert data["id"] == AshGraphql.Resource.encode_relay_id(part_number_record)
      assert data["partNumber"] == new_part_number
    end

    test "receive data on system model part number destroy", %{socket: socket, tenant: tenant} do
      part_number_record = system_model_part_number_fixture(tenant: tenant)
      subscribe(socket)

      Ash.destroy!(part_number_record, action: :destroy, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("systemModelPartNumber", destroyed_id, push)

      assert destroyed_id == AshGraphql.Resource.encode_relay_id(part_number_record)
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      systemModelPartNumber {
        created {
          id
          partNumber
        }
        updated {
          id
          partNumber
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
