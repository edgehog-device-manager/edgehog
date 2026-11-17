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

defmodule Edgehog.Audit.ResourceAuditTest do
  use Edgehog.DataCase, async: false

  import Edgehog.FilesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Audit.Event
  alias Edgehog.Config
  alias Edgehog.Containers.Network
  alias Edgehog.Groups.DeviceGroup

  setup do
    stub(Config, :audit_log_events?, fn -> false end)
    stub(Config, :audit_store_events?, fn -> true end)

    %{tenant: tenant_fixture()}
  end

  describe "audited resource actions" do
    test "registers events for create, update and destroy of a network", %{tenant: tenant} do
      network =
        Ash.create!(
          Network,
          %{
            label: "audit-network",
            driver: "bridge",
            internal: false,
            enable_ipv6: false,
            options: %{}
          },
          tenant: tenant
        )

      assert create_event = event_for(tenant, Network, :create)
      assert create_event.ash_action_info.action_type == :create
      assert create_event.log_level == :info
      assert %Ash.Union{type: :uuid, value: id} = create_event.ash_action_info.record_id
      assert id == network.id

      network
      |> Ash.Changeset.for_update(:update, %{label: "audit-network-updated"}, tenant: tenant)
      |> Ash.update!()

      assert update_event = event_for(tenant, Network, :update)
      assert update_event.ash_action_info.action_type == :update
      assert %Ash.Union{type: :uuid, value: id} = update_event.ash_action_info.record_id
      assert id == network.id

      Ash.destroy!(network, tenant: tenant)

      assert destroy_event = event_for(tenant, Network, :destroy)
      assert destroy_event.ash_action_info.action_type == :destroy
      assert %Ash.Union{type: :uuid, value: id} = destroy_event.ash_action_info.record_id
      assert id == network.id

      assert length(events_for(tenant)) == 3
    end

    test "does not register events for excluded fixture actions", %{tenant: tenant} do
      file = file_fixture(tenant: tenant)

      assert events_for(tenant) == []

      Ash.destroy!(file, action: :destroy_fixture, tenant: tenant)

      assert events_for(tenant) == []
    end

    test "registers events for bulk updates running through the atomic path", %{
      tenant: tenant
    } do
      group = device_group_fixture(tenant: tenant)

      # default bulk strategy is [:atomic]: this only succeeds if the audit
      # change implements atomic/3, and the after_action hook must still fire
      assert %Ash.BulkResult{status: :success} =
               Ash.bulk_update!([group], :unassign_channel, %{}, tenant: tenant)

      assert event = event_for(tenant, DeviceGroup, :unassign_channel)
      assert event.ash_action_info.action_type == :update
      assert %Ash.Union{type: :integer, value: id} = event.ash_action_info.record_id
      assert id == group.id
    end
  end

  defp events_for(tenant) do
    Ash.read!(Event, tenant: tenant)
  end

  defp event_for(tenant, resource_module, action_name) do
    tenant
    |> events_for()
    |> Enum.find(fn event ->
      event.ash_action_info &&
        event.ash_action_info.resource_module == resource_module &&
        event.ash_action_info.action_name == action_name
    end)
  end
end
