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

defmodule Edgehog.Triggers.IncomingData.Handlers.AvailableContainers do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers
  alias Edgehog.Devices

  @container_status_actions %{
    "Received" => {:mark_as_received, %{}},
    "Missing" => {:mark_as_missing, %{}},
    "Creating" => {:mark_as_creating, %{}},
    "Created" => {:mark_as_created, %{}},
    "Starting" => {:mark_as_starting, %{}},
    "Running" => {:mark_as_running, %{}},
    "Stopping" => {:mark_as_stopping, %{}},
    "Stopped" => {:mark_as_stopped, %{}},
    "Deleting" => {:mark_as_deleting, %{}},
    "Error" => {:mark_as_errored, %{}}
  }

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, tenant: tenant} = context

    device = Devices.fetch_device_by_identity!(device_id, realm_id, tenant: tenant)

    event.path
    |> String.split("/")
    |> handle_property(event.value, device.id, tenant)
  end

  defp handle_property(["", container_id, "status"], value, device_id, tenant),
    do: handle_status(container_id, value, device_id, tenant)

  defp handle_property(["", container_id, "exitCode"], value, device_id, tenant),
    do: update_container_deployment(container_id, device_id, %{exit_code: value}, tenant)

  defp handle_property(["", container_id, "health", "status"], value, device_id, tenant) do
    with {:ok, health_status} <- health_status(value) do
      update_container_deployment(
        container_id,
        device_id,
        %{health_status: health_status},
        tenant
      )
    end
  end

  defp handle_property(["", container_id, "health", "failed"], value, device_id, tenant),
    do:
      update_container_deployment(
        container_id,
        device_id,
        %{health_failed_count: value},
        tenant
      )

  defp handle_property(["", container_id, "restartCount"], value, device_id, tenant),
    do: update_container_deployment(container_id, device_id, %{restart_count: value}, tenant)

  defp handle_property(_path, _value, _device_id, _tenant), do: {:error, :invalid_event_path}

  defp handle_status(container_id, nil, device_id, tenant) do
    container_deployment =
      Containers.fetch_container_deployment!(container_id, device_id, tenant: tenant)

    Containers.destroy_container_deployment!(container_deployment, tenant: tenant)
    {:ok, container_deployment}
  end

  defp handle_status(container_id, status, device_id, tenant) do
    case Map.fetch(@container_status_actions, status) do
      {:ok, {action, params}} ->
        container_id
        |> Containers.fetch_container_deployment!(device_id, tenant: tenant)
        |> Ash.Changeset.for_update(action, params)
        |> Ash.update(tenant: tenant)

      :error ->
        {:error, {:unsupported_status, status}}
    end
  end

  defp update_container_deployment(container_id, device_id, attrs, tenant) do
    container_id
    |> Containers.fetch_container_deployment!(device_id, tenant: tenant)
    |> Containers.update_container_deployment_from_device(attrs, tenant: tenant)
  end

  defp health_status("None"), do: {:ok, :none}
  defp health_status("Starting"), do: {:ok, :starting}
  defp health_status("Healthy"), do: {:ok, :healthy}
  defp health_status("Unhealthy"), do: {:ok, :unhealthy}
  defp health_status(nil), do: {:ok, nil}
  defp health_status(_), do: {:error, :unsupported_health_status}
end
