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

defmodule Edgehog.Audit.EventTest do
  use Edgehog.DataCase, async: true

  import Edgehog.TenantsFixtures

  alias Ash.Error.Invalid
  alias Edgehog.Audit.Event

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "create/3" do
    test "creates an event with only a message", %{tenant: tenant} do
      assert {:ok, %Event{} = event} = create_event(%{message: "device registered"}, tenant)

      assert event.message == "device registered"
      assert event.log_level == :info
      assert event.metadata == %{}
      assert is_binary(event.id)
      assert %DateTime{} = event.inserted_at
      assert event.tenant_id == tenant.tenant_id
    end

    test "creates an event at every log level", %{tenant: tenant} do
      levels = [
        :emergency,
        :alert,
        :critical,
        :error,
        :warning,
        :notice,
        :info,
        :debug
      ]

      for level <- levels do
        assert {:ok, event} = create_event(%{message: "msg", log_level: level}, tenant)
        assert event.log_level == level
      end
    end

    test "round-trips metadata as jsonb, so atom keys become strings", %{tenant: tenant} do
      assert {:ok, event} =
               create_event(
                 %{message: "with metadata", metadata: %{device_id: 1, tags: ["a"]}},
                 tenant
               )

      assert event.metadata == %{"device_id" => 1, "tags" => ["a"]}
    end

    test "returns an error when a required value is missing", %{tenant: tenant} do
      assert {:error, error} = create_event(%{log_level: :warning}, tenant)
      assert error_on?(error, :message)

      assert {:error, error} = create_event(event_attrs(drop: [:resource_module]), tenant)
      assert error_on?(error, :resource_module)

      assert {:error, error} = create_event(event_attrs(drop: [:record_id]), tenant)
      assert error_on?(error, :record_id)

      assert {:error, error} = create_event(event_attrs(drop: [:action_inputs]), tenant)
      assert error_on?(error, :action_inputs)

      assert {:error, error} = create_event(event_attrs(drop: [:changed_attributes]), tenant)
      assert error_on?(error, :changed_attributes)
    end

    test "returns an error when a value or input is unknown", %{tenant: tenant} do
      assert {:error, error} = create_event(%{message: "msg", log_level: :verbose}, tenant)
      assert error_on?(error, :log_level)

      assert {:error, error} =
               create_event(event_attrs(put: %{action_type: :read_all_the_things}), tenant)

      assert error_on?(error, :action_type)

      assert {:error, error} = create_event(%{message: "msg", bogus: 1}, tenant)
      assert error_on?(error, :bogus)
    end

    test "creates an event with the expected action_action_info data", %{tenant: tenant} do
      record_id = Ash.UUIDv7.generate()

      attrs =
        event_attrs(
          put: %{
            record_id: record_id,
            action_inputs: %{tags: ["foobar"]},
            changed_attributes: %{last_seen_ip: "10.0.0.1"},
            actor: %{id: "subject-1", type: :user, name: "jane"}
          }
        )

      assert {:ok, event} = create_event(attrs, tenant)

      assert event.ash_action_info.resource_module == Edgehog.Devices.Device
      assert %Ash.Union{value: ^record_id, type: :uuid} = event.ash_action_info.record_id
      assert event.ash_action_info.action_name == :update
      assert event.ash_action_info.action_type == :update
      assert event.ash_action_info.action_inputs == %{"tags" => ["foobar"]}
      assert event.ash_action_info.changed_attributes == %{"last_seen_ip" => "10.0.0.1"}

      assert event.ash_action_info.actor == %{
               "id" => "subject-1",
               "name" => "jane",
               "type" => "user"
             }
    end

    test "allows the optional actor to be omitted on action_action_info", %{tenant: tenant} do
      assert {:ok, event} = create_event(event_attrs(), tenant)
      assert is_nil(event.ash_action_info[:actor])
    end
  end

  describe "read" do
    test "returns the events of the tenant", %{tenant: tenant} do
      assert {:ok, first} = create_event(%{message: "first"}, tenant)
      assert {:ok, second} = create_event(%{message: "second"}, tenant)

      events = Ash.read!(Event, tenant: tenant)
      by_message = Map.new(events, fn event -> {event.message, event.id} end)

      assert map_size(by_message) == 2
      assert by_message["first"] == first.id
      assert by_message["second"] == second.id
    end

    test "returns an empty list for a tenant without events" do
      other_tenant = tenant_fixture()

      assert Ash.read!(Event, tenant: other_tenant) == []
    end
  end

  describe "destroy" do
    test "removes the event", %{tenant: tenant} do
      assert {:ok, event} = create_event(%{message: "temporary"}, tenant)

      assert :ok = Ash.destroy(event, domain: Edgehog.Audit, tenant: tenant)

      assert Ash.read!(Event, tenant: tenant) == []
    end
  end

  defp create_event(attrs, tenant) do
    Event
    |> Ash.Changeset.for_create(:create, attrs, tenant: tenant)
    |> Ash.create()
  end

  defp event_attrs(opts \\ []) do
    ash_action_info =
      %{
        resource_module: Edgehog.Devices.Device,
        record_id: Ash.UUIDv7.generate(),
        action_name: :update,
        action_type: :update,
        action_inputs: %{},
        changed_attributes: %{}
      }
      |> Map.merge(Keyword.get(opts, :put, %{}))
      |> Map.drop(Keyword.get(opts, :drop, []))

    %{message: "device updated", ash_action_info: ash_action_info}
  end

  defp error_on?(%Invalid{errors: errors}, field) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.Required{field: ^field} -> true
      %Ash.Error.Changes.InvalidAttribute{field: ^field} -> true
      %Ash.Error.Invalid.NoSuchInput{input: ^field} -> true
      _ -> false
    end)
  end

  defp error_on?(_error, _field), do: false
end
