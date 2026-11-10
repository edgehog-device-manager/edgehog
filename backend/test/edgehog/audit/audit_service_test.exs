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

defmodule Edgehog.Audit.AuditServiceTest do
  use Edgehog.DataCase, async: false

  import Edgehog.TenantsFixtures
  import ExUnit.CaptureLog

  alias Edgehog.Audit.AuditService
  alias Edgehog.Audit.Event
  alias Edgehog.Config

  setup do
    log_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn ->
      Logger.configure(level: log_level)
    end)

    %{tenant: tenant_fixture()}
  end

  describe "register_event/5" do
    test "logs the message and creates the event resource when both are enabled", %{
      tenant: tenant
    } do
      stub(Config, :audit_log_events?, fn -> true end)
      stub(Config, :audit_store_events?, fn -> true end)

      record_id = Ash.UUIDv7.generate()
      ash_action_info = action_event_info(record_id)
      metadata = %{tag: "audit_test", device_id: 42}

      log =
        capture_log([level: :debug], fn ->
          assert :ok =
                   AuditService.register_event(
                     "device updated",
                     :warning,
                     ash_action_info,
                     metadata,
                     tenant: tenant
                   )
        end)

      assert log =~ "device updated"
      assert log =~ "tenant=#{tenant.slug}"
      assert log =~ "tag=audit_test"

      assert [event] = Ash.read!(Event, tenant: tenant)
      assert event.message == "device updated"
      assert event.log_level == :warning
      assert event.metadata == %{"tag" => "audit_test", "device_id" => 42}
      assert event.ash_action_info.resource_module == Edgehog.Devices.Device
      assert %Ash.Union{value: ^record_id, type: :uuid} = event.ash_action_info.record_id
      assert event.tenant_id == tenant.tenant_id
    end

    test "only logs the message and does not create an event when audit_store_events? is false",
         %{tenant: tenant} do
      stub(Config, :audit_log_events?, fn -> true end)
      stub(Config, :audit_store_events?, fn -> false end)

      log =
        capture_log([level: :debug], fn ->
          assert :ok =
                   AuditService.register_event(
                     "logged only event",
                     :info,
                     nil,
                     %{tag: "atom_key_meta"},
                     tenant: tenant
                   )
        end)

      assert log =~ "logged only event"
      assert log =~ "tag=atom_key_meta"
      assert Ash.read!(Event, tenant: tenant) == []
    end

    test "only creates the event and does not log when audit_log_events? is false", %{
      tenant: tenant
    } do
      stub(Config, :audit_log_events?, fn -> false end)
      stub(Config, :audit_store_events?, fn -> true end)

      log =
        capture_log([level: :debug], fn ->
          assert :ok =
                   AuditService.register_event(
                     "stored only event",
                     :notice,
                     nil,
                     %{key: "val"},
                     tenant: tenant
                   )
        end)

      assert log == ""

      assert [event] = Ash.read!(Event, tenant: tenant)
      assert event.message == "stored only event"
      assert event.log_level == :notice
      assert event.metadata == %{"key" => "val"}
    end

    test "neither logs nor creates an event when both configs are false", %{tenant: tenant} do
      stub(Config, :audit_log_events?, fn -> false end)
      stub(Config, :audit_store_events?, fn -> false end)

      log =
        capture_log([level: :debug], fn ->
          assert :ok =
                   AuditService.register_event(
                     "noop event",
                     :info,
                     nil,
                     %{},
                     tenant: tenant
                   )
        end)

      assert log == ""
      assert Ash.read!(Event, tenant: tenant) == []
    end

    test "returns {:error, reason} when event creation fails", %{tenant: tenant} do
      stub(Config, :audit_log_events?, fn -> false end)
      stub(Config, :audit_store_events?, fn -> true end)

      assert {:error, _reason} =
               AuditService.register_event(
                 "invalid level",
                 :not_a_valid_level,
                 nil,
                 %{},
                 tenant: tenant
               )

      assert Ash.read!(Event, tenant: tenant) == []
    end
  end

  describe "convenience functions" do
    test "info/2, warning/2, error/2 and debug/2 use the correct log levels", %{
      tenant: tenant
    } do
      stub(Config, :audit_log_events?, fn -> false end)
      stub(Config, :audit_store_events?, fn -> true end)

      assert :ok = AuditService.info("info event", tenant: tenant)
      assert :ok = AuditService.warning("warning event", tenant: tenant)
      assert :ok = AuditService.error("error event", tenant: tenant)
      assert :ok = AuditService.debug("debug event", tenant: tenant)

      events = Ash.read!(Event, tenant: tenant)

      assert length(events) == 4

      assert Map.new(events, &{&1.message, &1.log_level}) == %{
               "info event" => :info,
               "warning event" => :warning,
               "error event" => :error,
               "debug event" => :debug
             }
    end

    test "convenience functions pass metadata and Ash action information", %{tenant: tenant} do
      stub(Config, :audit_log_events?, fn -> false end)
      stub(Config, :audit_store_events?, fn -> true end)

      record_id = Ash.UUIDv7.generate()
      ash_action_info = action_event_info(record_id)

      assert :ok =
               AuditService.info(
                 "event with details",
                 tenant: tenant,
                 metadata: %{resource_type: "container_deployment"},
                 ash_action_info: ash_action_info
               )

      assert [event] = Ash.read!(Event, tenant: tenant)
      assert event.message == "event with details"
      assert event.metadata == %{"resource_type" => "container_deployment"}
      assert event.ash_action_info.resource_module == Edgehog.Devices.Device
      assert %Ash.Union{value: ^record_id, type: :uuid} = event.ash_action_info.record_id
      assert event.tenant_id == tenant.tenant_id
    end
  end

  defp action_event_info(record_id) do
    %{
      resource_module: Edgehog.Devices.Device,
      record_id: record_id,
      action_name: :update,
      action_type: :update,
      action_inputs: %{tags: ["foobar"]},
      changed_attributes: %{online: true}
    }
  end
end
