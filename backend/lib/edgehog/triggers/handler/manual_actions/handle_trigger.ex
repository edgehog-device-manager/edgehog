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
  use Ash.Resource.Actions.Implementation

  alias Edgehog.Astarte.Realm
  alias Edgehog.Devices.Device
  alias Edgehog.Triggers.DeviceConnected
  alias Edgehog.Triggers.DeviceDisconnected
  alias Edgehog.Triggers.IncomingData
  alias Edgehog.Triggers.TriggerPayload

  @ota_event "io.edgehog.devicemanager.OTAEvent"
  @ota_response "io.edgehog.devicemanager.OTAResponse"
  @system_info "io.edgehog.devicemanager.SystemInfo"

  @impl true
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

    with {:ok, realm} <- Realm.fetch_by_name(realm_name, query: read_query, tenant: tenant),
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

  defp handle_event(
         %IncomingData{interface: @ota_event, path: "/event"} = _event,
         _tenant,
         _realm_id,
         _device_id,
         _timestamp
       ) do
    # TODO: implement when we port OS Management context
    raise "Not implemented"
  end

  defp handle_event(
         %IncomingData{interface: @ota_response, path: "/response"} = _event,
         _tenant,
         _realm_id,
         _device_id,
         _timestamp
       ) do
    # TODO: implement when we port OS Management context
    raise "Not implemented"
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
