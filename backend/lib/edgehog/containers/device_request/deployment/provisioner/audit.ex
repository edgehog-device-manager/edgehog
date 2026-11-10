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

defmodule Edgehog.Containers.DeviceRequest.Deployment.Provisioner.Audit do
  @moduledoc """
  The module describing the Audit functions for the device request deployment provisioner.

  For more information, check the `Edgehog.Provisioner.Audit.Behaviour` docs.
  """
  use Edgehog.Provisioner.Audit

  alias Edgehog.Audit.AuditService
  alias Edgehog.Containers.DeviceRequest.Deployment.Provisioner.Core
  alias Edgehog.Containers.Telemetry

  @impl Edgehog.Provisioner.Audit.Behaviour
  def provisioning_started(resource, context) do
    Telemetry.provisioning_started(resource, context)
  end

  @impl Edgehog.Provisioner.Audit.Behaviour
  def sent_to_device(resource, device, tenant) do
    AuditService.info(
      "DeviceRequest #{resource.id} sent to device #{device.device_id}.",
      tenant: tenant,
      metadata: %{
        resource_type: "device_request_deployment",
        resource_id: resource.id,
        device_id: device.device_id
      }
    )
  end

  @impl Edgehog.Provisioner.Audit.Behaviour
  def api_error(resource, error, tenant) do
    {log_level, message} =
      if Core.temporary_error?(error) do
        {:warning,
         "Error while sending the device request #{resource.id}: #{inspect(error)}. The operation will be retried shortly."}
      else
        {:error,
         "Unrecoverable error while sending the device request #{resource.id}: #{inspect(error)}. Terminating."}
      end

    AuditService.register_event(
      message,
      log_level,
      nil,
      %{
        resource_type: "device_request_deployment",
        resource_id: resource.id,
        error: inspect(error)
      },
      tenant: tenant
    )
  end

  @impl Edgehog.Provisioner.Audit.Behaviour
  def provisioning_completed(resource, context, started_at, retries, result) do
    tenant = Keyword.fetch!(context, :tenant)

    AuditService.info(
      "DeviceRequest #{resource.id} successfully provisioned after #{retries} retries.",
      tenant: tenant,
      metadata: %{
        resource_type: "device_request_deployment",
        resource_id: resource.id,
        retries: retries
      }
    )

    Telemetry.provisioning_completed(resource, context, started_at, retries, result)
  end

  @impl Edgehog.Provisioner.Audit.Behaviour
  def provisioning_failed(resource, context, started_at, retries, reason) do
    tenant = Keyword.fetch!(context, :tenant)

    AuditService.info(
      "Provisioner for device request #{resource.id} gave up with reason #{inspect(reason)}.",
      tenant: tenant,
      metadata: %{
        resource_type: "device_request_deployment",
        resource_id: resource.id,
        retries: retries,
        reason: inspect(reason)
      }
    )

    Telemetry.provisioning_failed(resource, context, started_at, retries, reason)
  end
end
