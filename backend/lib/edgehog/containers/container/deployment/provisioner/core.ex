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

defmodule Edgehog.Containers.Container.Deployment.Provisioner.Core do
  @moduledoc """
  The module describing the Core functions required by the container deployment provisioner.

  For more information, check the `Edgehog.Containers.Provisioner.Core.Behaviour` docs.
  """
  use Edgehog.Containers.Provisioner.Core

  alias Edgehog.Astarte.Device.AvailableContainers.ContainerStatus
  alias Edgehog.Devices

  require Logger

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def ready?(%{state: state}), do: state in [:received, :device_created, :stopped, :running]

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def topic(%{id: id}), do: "container_deployments:provisioning:#{id}"
  def topic(id), do: "container_deployments:provisioning:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def subscribe_topic(%{id: id}), do: "container_deployments:#{id}"
  def subscribe_topic(id), do: "container_deployments:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def name(%{id: id}),
    do: {:via, Registry, {Edgehog.Containers.Container.Deployment.Provisioner.Registry, id}}

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def send_to_device(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, actual_resource} <- Ash.load(resource, [:container, :device], tenant: tenant),
         {:ok, device} <- Map.fetch(actual_resource, :device),
         {:ok, device} <-
           Devices.send_create_container_request(device, actual_resource, deployment,
             tenant: tenant
           ) do
      log_provisioning_started(actual_resource, device)
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def reconcile(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, resource} <-
           Ash.load(resource, [container: [], device: [:available_containers]], tenant: tenant),
         {:ok, actual_resource} <- Map.fetch(resource, :container),
         {:ok, device} <- Map.fetch(resource, :device),
         {:ok, available_resources} <- Map.fetch(device, :available_containers) do
      available_resources
      |> Enum.find(:not_found, &(&1.id == actual_resource.id))
      |> maybe_update(resource, tenant)
    end
  end

  def maybe_update(%ContainerStatus{status: status}, resource, tenant) do
    action =
      case status do
        "Received" -> :mark_as_received
        "Created" -> :mark_as_created
        "Running" -> :mark_as_running
        "Stopped" -> :mark_as_stopped
      end

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
    Container #{resource.id} provisioned on device #{device.device_id}. Waiting events
    """)
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_api_error(resource, error) do
    if temporary_error?(error) do
      Logger.warning(
        "Error while sending the container #{resource.id}: #{inspect(error)}. The operation will be retried shortly."
      )
    else
      Logger.error(
        "Unrecoverable error while sending the container #{resource.id}: #{inspect(error)}. Terminating."
      )
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_failed(resource, reason) do
    Logger.info(
      "Provisioner for container #{resource.id} gave up with reason #{inspect(reason)}."
    )
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_completed(resource, retries) do
    Logger.info("Container #{resource.id} successfully provisioned after #{retries} retries.")
  end
end
