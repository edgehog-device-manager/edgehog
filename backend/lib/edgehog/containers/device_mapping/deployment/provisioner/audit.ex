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

defmodule Edgehog.Containers.DeviceMapping.Deployment.Provisioner.Audit do
  @moduledoc """
  The module describing the Audit functions for the device mapping deployment provisioner.

  For more information, check the `Edgehog.Provisioner.Audit.Behaviour` docs.
  """
  use Edgehog.Provisioner.Audit

  alias Edgehog.Containers.DeviceMapping.Deployment.Provisioner.Core
  alias Edgehog.Containers.Telemetry

  require Logger

  @impl Edgehog.Provisioner.Audit.Behaviour
  def provisioning_started(resource, context) do
    Telemetry.provisioning_started(resource, context)
  end

  @impl Edgehog.Provisioner.Audit.Behaviour
  def sent_to_device(resource, device) do
    Logger.info("""
    DeviceMapping #{resource.id} provisioned on device #{device.device_id}. Waiting events
    """)
  end

  @impl Edgehog.Provisioner.Audit.Behaviour
  def api_error(resource, error) do
    if Core.temporary_error?(error) do
      Logger.warning(
        "Error while sending the device mapping #{resource.id}: #{inspect(error)}. The operation will be retried shortly."
      )
    else
      Logger.error(
        "Unrecoverable error while sending the device mapping #{resource.id}: #{inspect(error)}. Terminating."
      )
    end
  end

  @impl Edgehog.Provisioner.Audit.Behaviour
  def provisioning_completed(resource, context, started_at, retries, result) do
    Logger.info("DeviceMapping #{resource.id} successfully provisioned after #{retries} retries.")
    Telemetry.provisioning_completed(resource, context, started_at, retries, result)
  end

  @impl Edgehog.Provisioner.Audit.Behaviour
  def provisioning_failed(resource, context, started_at, retries, reason) do
    Logger.info(
      "Provisioner for device mapping #{resource.id} gave up with reason #{inspect(reason)}."
    )

    Telemetry.provisioning_failed(resource, context, started_at, retries, reason)
  end
end
