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

defmodule Edgehog.Containers.DeviceMapping.Deployment.Provisioner.Core do
  @moduledoc """
  The module describing the Core functions required by the device mapping deployment provisioner.

  For more information, check the `Edgehog.Containers.Provisioner.Core.Behaviour` docs.
  """
  use Edgehog.Containers.Provisioner.Core

  alias Edgehog.Astarte.Device.AvailableDeviceMappings.DeviceMappingStatus
  alias Edgehog.Devices

  require Logger

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def ready?(%{state: state}), do: state in [:present, :not_present]

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def topic(%{id: id}), do: "ready:device_mapping_deployments:#{id}"
  def topic(id), do: "ready:device_mapping_deployments:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def subscribe_topic(%{id: id}), do: "device_mapping_deployments:#{id}"
  def subscribe_topic(id), do: "device_mapping_deployments:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def name(%{id: id}),
    do: {:via, Registry, {Edgehog.Containers.DeviceMapping.Deployment.Provisioner.Registry, id}}

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def send_to_device(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, resource} <- Ash.load(resource, [:device_mapping, :device], tenant: tenant),
         {:ok, actual_resource} <- Map.fetch(resource, :device_mapping),
         {:ok, device} <- Map.fetch(resource, :device),
         {:ok, device} <-
           Devices.send_create_device_mapping_request(device, actual_resource, deployment,
             tenant: tenant
           ) do
      log_provisioning_started(actual_resource, device)
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def reconcile(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, resource} <-
           Ash.load(
             resource,
             [device_mapping: [], device: [:available_device_mappings]],
             tenant: tenant
           ),
         {:ok, actual_resource} <- Map.fetch(resource, :device_mapping),
         {:ok, device} <- Map.fetch(resource, :device),
         {:ok, available_resources} <- Map.fetch(device, :available_device_mappings) do
      available_resources
      |> Enum.find(:not_found, &(&1.id == actual_resource.id))
      |> maybe_update(resource, tenant)
    end
  end

  def maybe_update(%DeviceMappingStatus{present: present}, resource, tenant) do
    action =
      if present,
        do: :mark_as_present,
        else: :mark_as_not_present

    # NOTE: this will trigger a publish on the appropriate topic, the
    # provisioner will react to it.
    resource
    |> Ash.Changeset.for_update(action)
    |> Ash.update(tenant: tenant)
  end

  def maybe_update(other, _resource, _tenant), do: other

  # Logging functions

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_started(resource, device) do
    Logger.info("""
    DeviceMapping #{resource.id} provisioned on device #{device.device_id}. Waiting events
    """)
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_api_error(resource, error) do
    if temporary_error?(error) do
      Logger.warning(
        "Error while sending the device mapping #{resource.id}: #{inspect(error)}. The operation will be retried shortly."
      )
    else
      Logger.error(
        "Unrecoverable error while sending the device mapping #{resource.id}: #{inspect(error)}. Terminating."
      )
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_failed(resource, reason) do
    Logger.info(
      "Provisioner for device mapping #{resource.id} gave up with reason #{inspect(reason)}."
    )
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_completed(resource, retries) do
    Logger.info("DeviceMapping #{resource.id} successfully provisioned after #{retries} retries.")
  end
end
