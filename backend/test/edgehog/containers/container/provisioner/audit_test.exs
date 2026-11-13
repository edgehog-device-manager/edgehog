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

defmodule Edgehog.Containers.Container.Deployment.Provisioner.AuditTest do
  use Edgehog.DataCase, async: false

  import Edgehog.TenantsFixtures

  alias Edgehog.Audit.Event
  alias Edgehog.Config
  alias Edgehog.Containers.Container.Deployment.Provisioner.Audit

  setup do
    stub(Config, :audit_log_events?, fn -> false end)
    stub(Config, :audit_store_events?, fn -> true end)

    %{tenant: tenant_fixture()}
  end

  test "registers an audit event when a container is sent to a device", %{
    tenant: tenant
  } do
    resource_id = Ash.UUIDv7.generate()
    device_id = "test-device-id"

    assert :ok =
             Audit.sent_to_device(
               %{id: resource_id},
               %{device_id: device_id},
               tenant
             )

    assert [event] = Ash.read!(Event, tenant: tenant)

    assert event.message ==
             "Container #{resource_id} sent to device #{device_id}."

    assert event.log_level == :info

    assert event.metadata == %{
             "resource_type" => "container_deployment",
             "resource_id" => resource_id,
             "device_id" => device_id
           }

    assert event.tenant_id == tenant.tenant_id
  end

  test "registers an audit event when provisioning encounters an API error", %{
    tenant: tenant
  } do
    resource_id = Ash.UUIDv7.generate()
    error = :invalid_request

    assert :ok = Audit.api_error(%{id: resource_id}, error, tenant)

    assert [event] = Ash.read!(Event, tenant: tenant)

    assert event.message ==
             "Unrecoverable error while sending the container #{resource_id}: #{inspect(error)}. Terminating."

    assert event.log_level == :error

    assert event.metadata == %{
             "resource_type" => "container_deployment",
             "resource_id" => resource_id,
             "error" => inspect(error)
           }

    assert event.tenant_id == tenant.tenant_id
  end

  test "registers an audit event when provisioning completes", %{tenant: tenant} do
    resource_id = Ash.UUIDv7.generate()

    resource =
      struct(Edgehog.Containers.Container.Deployment, id: resource_id)

    context = [tenant: tenant]
    retries = 2

    assert :ok =
             Audit.provisioning_completed(
               resource,
               context,
               System.monotonic_time(),
               retries,
               :ok
             )

    assert [event] = Ash.read!(Event, tenant: tenant)

    assert event.message ==
             "Container #{resource_id} successfully provisioned after #{retries} retries."

    assert event.log_level == :info

    assert event.metadata == %{
             "resource_type" => "container_deployment",
             "resource_id" => resource_id,
             "retries" => retries
           }

    assert event.tenant_id == tenant.tenant_id
  end

  test "registers an audit event when provisioning fails", %{tenant: tenant} do
    resource_id = Ash.UUIDv7.generate()

    resource =
      struct(Edgehog.Containers.Container.Deployment, id: resource_id)

    context = [tenant: tenant]
    retries = 3
    reason = :device_unavailable

    assert :ok =
             Audit.provisioning_failed(
               resource,
               context,
               System.monotonic_time(),
               retries,
               reason
             )

    assert [event] = Ash.read!(Event, tenant: tenant)

    assert event.message ==
             "Provisioner for container #{resource_id} gave up with reason #{inspect(reason)}."

    assert event.log_level == :info

    assert event.metadata == %{
             "resource_type" => "container_deployment",
             "resource_id" => resource_id,
             "retries" => retries,
             "reason" => inspect(reason)
           }

    assert event.tenant_id == tenant.tenant_id
  end
end
