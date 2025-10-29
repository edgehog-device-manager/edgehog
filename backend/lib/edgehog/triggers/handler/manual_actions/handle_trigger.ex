#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

  alias Edgehog.Astarte
  alias Edgehog.Astarte.Realm
  alias Edgehog.Containers
  alias Edgehog.Devices
  alias Edgehog.Devices.Device
  alias Edgehog.OSManagement
  alias Edgehog.Triggers.DeviceConnected
  alias Edgehog.Triggers.DeviceDisconnected
  alias Edgehog.Triggers.DeviceRegistered
  alias Edgehog.Triggers.IncomingData
  alias Edgehog.Triggers.TriggerPayload

  require Logger

  @available_containers "io.edgehog.devicemanager.apps.AvailableContainers"
  @available_deployments "io.edgehog.devicemanager.apps.AvailableDeployments"
  @available_images "io.edgehog.devicemanager.apps.AvailableImages"
  @available_networks "io.edgehog.devicemanager.apps.AvailableNetworks"
  @available_volumes "io.edgehog.devicemanager.apps.AvailableVolumes"
  @available_device_mappings "io.edgehog.devicemanager.apps.AvailableDeviceMappings"
  @deployment_event "io.edgehog.devicemanager.apps.DeploymentEvent"
  @ota_event "io.edgehog.devicemanager.OTAEvent"
  @ota_response "io.edgehog.devicemanager.OTAResponse"
  @system_info "io.edgehog.devicemanager.SystemInfo"

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

  defp handle_event(%DeviceRegistered{}, tenant, realm_id, device_id, _timestamp) do
    params = %{realm_id: realm_id, device_id: device_id}

    Device
    |> Ash.Changeset.for_create(:from_device_registered_event, params)
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

  defp handle_event(%IncomingData{interface: @available_images} = event, tenant, realm_id, device_id, _timestamp) do
    device = Devices.fetch_device_by_identity!(device_id, realm_id, tenant: tenant)

    case String.split(event.path, "/") do
      ["", image_id, "pulled"] ->
        image_deployment =
          Containers.fetch_image_deployment!(image_id, device.id, tenant: tenant)

        case event.value do
          true ->
            Containers.mark_image_deployment_as_pulled(image_deployment, tenant: tenant)

          false ->
            Containers.mark_image_deployment_as_unpulled(image_deployment, tenant: tenant)

          nil ->
            Containers.destroy_image_deployment!(image_deployment, tenant: tenant)
            {:ok, image_deployment}
        end

      _ ->
        {:error, :invalid_event_path}
    end
  end

  defp handle_event(%IncomingData{interface: @available_networks} = event, tenant, realm_id, device_id, _timestamp) do
    device = Devices.fetch_device_by_identity!(device_id, realm_id, tenant: tenant)

    case String.split(event.path, "/") do
      ["", network_id, "created"] ->
        network_deployment =
          Containers.fetch_network_deployment!(network_id, device.id, tenant: tenant)

        case event.value do
          true ->
            Containers.mark_network_deployment_as_available(network_deployment, tenant: tenant)

          false ->
            Containers.mark_network_deployment_as_unavailable(network_deployment, tenant: tenant)

          nil ->
            Containers.destroy_network_deployment!(network_deployment, tenant: tenant)
            {:ok, network_deployment}
        end

      _ ->
        {:error, :invalid_event_path}
    end
  end

  defp handle_event(%IncomingData{interface: @available_volumes} = event, tenant, realm_id, device_id, _timestamp) do
    device = Devices.fetch_device_by_identity!(device_id, realm_id, tenant: tenant)

    case String.split(event.path, "/") do
      ["", volume_id, "created"] ->
        volume_deployment =
          Containers.fetch_volume_deployment!(volume_id, device.id, tenant: tenant)

        case event.value do
          true ->
            Containers.mark_volume_deployment_as_available(volume_deployment, tenant: tenant)

          false ->
            Containers.mark_volume_deployment_as_unavailable(volume_deployment, tenant: tenant)

          # The volume has been removed on the device, we should remove it too.
          nil ->
            Containers.destroy_volume_deployment!(volume_deployment, tenant: tenant)
            {:ok, volume_deployment}
        end

      _ ->
        {:error, :invalid_event_path}
    end
  end

  defp handle_event(%IncomingData{interface: @available_device_mappings} = event, tenant, realm_id, device_id, _timestamp) do
    device = Devices.fetch_device_by_identity!(device_id, realm_id, tenant: tenant)

    case String.split(event.path, "/") do
      ["", device_mapping_id, "present"] ->
        device_mapping_deployment =
          Containers.fetch_device_mapping_deployment!(device_mapping_id, device.id, tenant: tenant)

        case event.value do
          true ->
            Containers.mark_device_mapping_deployment_as_present(device_mapping_deployment,
              tenant: tenant
            )

          false ->
            Containers.mark_device_mapping_deployment_as_not_present(device_mapping_deployment,
              tenant: tenant
            )

          # The device mapping has been removed on the device. We should remove it too.
          nil ->
            Containers.destroy_device_mapping_deployment(device_mapping_deployment,
              tenant: tenant
            )

            {:ok, device_mapping_deployment}
        end

      _ ->
        {:error, :invalid_event_path}
    end
  end

  defp handle_event(%IncomingData{interface: @available_containers} = event, tenant, realm_id, device_id, _timestamp) do
    device = Devices.fetch_device_by_identity!(device_id, realm_id, tenant: tenant)

    case String.split(event.path, "/") do
      ["", container_id, "status"] ->
        container_deployment =
          Containers.fetch_container_deployment!(container_id, device.id, tenant: tenant)

        # Pure side effects
        case event.value do
          "Received" ->
            Containers.mark_container_deployment_as_received(container_deployment,
              tenant: tenant
            )

          "Created" ->
            Containers.mark_container_deployment_as_created(container_deployment, tenant: tenant)

          "Running" ->
            Containers.mark_container_deployment_as_running(container_deployment, tenant: tenant)

          "Stopped" ->
            Containers.mark_container_deployment_as_stopped(container_deployment, tenant: tenant)

          # The container has been deleted, astarte is purgin properties on the available container
          nil ->
            Containers.destroy_container_deployment!(container_deployment, tenant: tenant)
            {:ok, container_deployment}
        end

      _ ->
        {:error, :invalid_event_path}
    end
  end

  defp handle_event(%IncomingData{interface: @deployment_event} = event, tenant, _realm_id, _device_id, _timestamp) do
    "/" <> deployment_id = event.path

    %{
      "status" => state,
      "message" => message
    } = event.value

    with {:ok, deployment} <- Containers.fetch_deployment(deployment_id, tenant: tenant) do
      event = %{type: state, message: message}

      Containers.append_deployment_event(deployment, %{event: event}, tenant: tenant)
    end
  end

  defp handle_event(%IncomingData{interface: @available_deployments} = event, tenant, _realm_id, _device_id, _timestamp) do
    case String.split(event.path, "/") do
      ["", deployment_id, "status"] ->
        state = event.value

        with {:ok, deployment} <- Containers.fetch_deployment(deployment_id, tenant: tenant) do
          case state do
            "Started" ->
              Containers.mark_deployment_as_started(deployment, tenant: tenant)
              Containers.deployment_update_resources_state(deployment, tenant: tenant)

            "Stopped" ->
              Containers.mark_deployment_as_stopped(deployment, tenant: tenant)
              Containers.deployment_update_resources_state(deployment, tenant: tenant)

            # The device is removing the deployment, remove it!
            nil ->
              deployment
              |> Ash.Changeset.for_destroy(:destroy_and_gc, %{}, tenant: tenant)
              |> Ash.destroy()

              {:ok, deployment}
          end
        end

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
