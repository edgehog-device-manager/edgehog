#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Triggers.Handler.ManualActions.HandleTrigger do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Edgehog.PubSub
  alias Edgehog.Astarte
  alias Edgehog.Astarte.Realm
  alias Edgehog.Containers
  alias Edgehog.Devices.Device
  alias Edgehog.OSManagement
  alias Edgehog.Triggers.DeviceConnected
  alias Edgehog.Triggers.DeviceDisconnected
  alias Edgehog.Triggers.IncomingData
  alias Edgehog.Triggers.TriggerPayload

  @available_containers "io.edgehog.devicemanager.apps.AvailableContainers"
  @available_deployments "io.edgehog.devicemanager.apps.AvailableDeployments"
  @available_images "io.edgehog.devicemanager.apps.AvailableImages"
  @available_networks "io.edgehog.devicemanager.apps.AvailableNetworks"
  @deployment_event "io.edgehog.devicemanager.apps.DeploymentEvent"
  @ota_event "io.edgehog.devicemanager.OTAEvent"
  @ota_response "io.edgehog.devicemanager.OTAResponse"
  @system_info "io.edgehog.devicemanager.SystemInfo"

  @initial_statuses [
    :created,
    :sent,
    :created_images,
    :created_networks,
    :created_containers,
    :created_deployment
  ]

  @impl Ash.Resource.Actions.Implementation
  def run(input, _opts, _context) do
    realm_name = input.arguments.realm_name
    tenant = input.tenant

    %TriggerPayload{
      device_id: device_id,
      timestamp: timestamp,
      event: %Ash.Union{value: event}
    } = input.arguments.trigger_payload

    # We only need the realm id and the tenant id, so we only read those
    read_query =
      Realm
      |> Ash.Query.select([:id])
      |> Ash.Query.load(tenant: [:tenant_id])

    with {:ok, realm} <-
           Astarte.fetch_realm_by_name(realm_name, query: read_query, tenant: tenant),
         {:ok, _} <- handle_event(event, realm.tenant, realm.id, device_id, timestamp) do
      :ok
    end
  end

  defp handle_event(%DeviceConnected{}, tenant, realm_id, device_id, timestamp) do
    params = %{realm_id: realm_id, device_id: device_id, timestamp: timestamp}

    Device
    |> Ash.Changeset.for_create(:from_device_connected_event, params)
    |> Ash.create(tenant: tenant)
  end

  defp handle_event(%DeviceDisconnected{}, tenant, realm_id, device_id, timestamp) do
    params = %{realm_id: realm_id, device_id: device_id, timestamp: timestamp}

    Device
    |> Ash.Changeset.for_create(:from_device_disconnected_event, params)
    |> Ash.create(tenant: tenant)
  end

  defp handle_event(
         %IncomingData{interface: @system_info, path: "/serialNumber"} = event,
         tenant,
         realm_id,
         device_id,
         _timestamp
       ) do
    params = %{realm_id: realm_id, device_id: device_id, serial_number: event.value}

    Device
    |> Ash.Changeset.for_create(:from_serial_number_event, params)
    |> Ash.create(tenant: tenant)
  end

  defp handle_event(
         %IncomingData{interface: @system_info, path: "/partNumber"} = event,
         tenant,
         realm_id,
         device_id,
         _timestamp
       ) do
    params = %{realm_id: realm_id, device_id: device_id, part_number: event.value}

    Device
    |> Ash.Changeset.for_create(:from_part_number_event, params)
    |> Ash.create(tenant: tenant)
  end

  defp handle_event(%IncomingData{interface: @available_images} = event, _tenant, _realm_id, _device_id, _timestamp) do
    case String.split(event.path, "/") do
      ["", image_id, "pulled"] ->
        PubSub.publish!({:available_image, image_id}, event.value)

      _ ->
        {:error, :invalid_event_path}
    end
  end

  defp handle_event(%IncomingData{interface: @available_networks} = event, _tenant, _realm_id, _device_id, _timestamp) do
    case String.split(event.path, "/") do
      ["", network_id, "created"] ->
        PubSub.publish!({:available_network, network_id}, event.value)

      _ ->
        {:error, :invalid_event_path}
    end
  end

  defp handle_event(%IncomingData{interface: @available_containers} = event, _tenant, _realm_id, _device_id, _timestamp) do
    case String.split(event.path, "/") do
      ["", container_id, "status"] ->
        PubSub.publish!({:available_container, container_id}, event.value)

      _ ->
        {:error, :invalid_event_path}
    end
  end

  defp handle_event(%IncomingData{interface: @deployment_event} = event, tenant, _realm_id, _device_id, _timestamp) do
    "/" <> deployment_id = event.path

    %{
      "status" => status,
      "message" => message
    } = event.value

    with {:ok, deployment} <- Containers.fetch_deployment(deployment_id, tenant: tenant) do
      case {deployment.status, status} do
        {:started, "Starting"} ->
          # Skip Starting if already Started
          {:ok, deployment}

        {:stopped, "Stopping"} ->
          # Skip Stopping if already Stopped
          {:ok, deployment}

        {_, "Error"} ->
          # Errors have precedence
          Containers.deployment_set_status(deployment, status, message, tenant: tenant)

        _ ->
          if deployment.status in @initial_statuses,
            do: Containers.deployment_update_status(deployment, tenant: tenant),
            else: Containers.deployment_set_status(deployment, status, message, tenant: tenant)
      end
    end
  end

  defp handle_event(%IncomingData{interface: @available_deployments} = event, _tenant, _realm_id, _device_id, _timestamp) do
    case String.split(event.path, "/") do
      ["", deployment_id, "status"] ->
        PubSub.publish!({:available_deployment, deployment_id}, event.value)

      _ ->
        {:error, :unsupported_event_path}
    end
  end

  defp handle_event(
         %IncomingData{interface: @ota_event, path: "/event"} = event,
         tenant,
         _realm_id,
         _device_id,
         _timestamp
       ) do
    ota_operation_id = event.value["requestUUID"]
    status = event.value["status"]
    status_progress = event.value["statusProgress"]
    # Note: statusCode and message could be nil
    status_code = event.value["statusCode"]
    message = event.value["message"]

    status_attrs = %{
      status_progress: status_progress,
      status_code: status_code,
      message: message
    }

    with {:ok, ota_operation} <-
           OSManagement.fetch_ota_operation(ota_operation_id, tenant: tenant) do
      OSManagement.update_ota_operation_status(ota_operation, status, status_attrs)
    end
  end

  defp handle_event(
         %IncomingData{interface: @ota_response, path: "/response"} = event,
         tenant,
         _realm_id,
         _device_id,
         _timestamp
       ) do
    ota_operation_id = event.value["uuid"]
    # Translate the status and status code to the new OTAEvent format
    status = translate_ota_response_status(event.value["status"])
    # Note: statusCode could be nil
    status_code = translate_ota_response_status_code(event.value["statusCode"])

    status_attrs = %{
      status_code: status_code
    }

    with {:ok, ota_operation} <-
           OSManagement.fetch_ota_operation(ota_operation_id, tenant: tenant) do
      OSManagement.update_ota_operation_status(ota_operation, status, status_attrs)
    end
  end

  defp handle_event(_unhandled_event, tenant, realm_id, device_id, _timestamp) do
    Device
    |> Ash.Changeset.for_create(:from_unhandled_event, %{realm_id: realm_id, device_id: device_id})
    |> Ash.create(tenant: tenant)
  end

  # TODO: needed for backwards compatibility, delete when we drop support for OTAResponse
  defp translate_ota_response_status("InProgress"), do: "Acknowledged"
  defp translate_ota_response_status("Error"), do: "Failure"
  defp translate_ota_response_status("Done"), do: "Success"

  defp translate_ota_response_status_code(nil), do: nil
  defp translate_ota_response_status_code(""), do: nil
  defp translate_ota_response_status_code("OTAErrorNetwork"), do: "NetworkError"
  defp translate_ota_response_status_code("OTAErrorNvs"), do: nil
  defp translate_ota_response_status_code("OTAAlreadyInProgress"), do: "UpdateAlreadyInProgress"
  defp translate_ota_response_status_code("OTAFailed"), do: nil
  defp translate_ota_response_status_code("OTAErrorDeploy"), do: "IOError"
  defp translate_ota_response_status_code("OTAErrorBootWrongPartition"), do: "SystemRollback"
end
