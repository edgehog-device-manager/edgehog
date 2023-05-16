#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule EdgehogWeb.AstarteTriggerController do
  use EdgehogWeb, :controller

  alias Edgehog.Astarte
  alias Edgehog.OSManagement

  require Logger

  @ota_event_interface "io.edgehog.devicemanager.OTAEvent"
  @ota_response_interface "io.edgehog.devicemanager.OTAResponse"

  # TODO: split incoming triggers with a dedicated shunt so we can route them in a clearer way
  def process_event(conn, %{
        "event" => %{
          "type" => "incoming_data",
          "interface" => @ota_event_interface,
          "path" => "/event",
          "value" => value
        }
      }) do
    %{
      "requestUUID" => uuid,
      "status" => status,
      "statusProgress" => status_progress
    } = value

    # statusCode and message could be nil, so we match them separately
    status_code = value["statusCode"]
    message = value["message"]

    ota_operation = OSManagement.get_ota_operation!(uuid)

    attrs = %{
      status: status,
      status_code: status_code,
      status_progress: status_progress,
      message: message
    }

    case OSManagement.update_ota_operation(ota_operation, attrs) do
      {:ok, _ota_operation} ->
        send_resp(conn, :ok, "")

      {:error, reason} ->
        Logger.warning("Invalid OTAEvent: #{inspect(reason)}")
        send_resp(conn, :bad_request, "")
    end
  end

  # TODO: needed for backwards compatibility, delete when we drop support for OTAResponse
  def process_event(conn, %{
        "event" => %{
          "type" => "incoming_data",
          "interface" => @ota_response_interface,
          "path" => "/response",
          "value" => value
        }
      }) do
    %{
      "uuid" => uuid,
      "status" => status
    } = value

    # statusCode could be nil, so we match it separately
    status_code = value["statusCode"]

    ota_operation = OSManagement.get_ota_operation!(uuid)
    # Translate the status and status code to the new OTAEvent format
    attrs = %{
      status: translate_ota_response_status(status),
      status_code: translate_ota_response_status_code(status_code)
    }

    case OSManagement.update_ota_operation(ota_operation, attrs) do
      {:ok, _ota_operation} ->
        send_resp(conn, :ok, "")

      {:error, reason} ->
        Logger.warning("Invalid OTAResponse: #{inspect(reason)}")
        send_resp(conn, :bad_request, "")
    end
  end

  def process_event(conn, %{
        "device_id" => device_id,
        "event" => event,
        "timestamp" => timestamp
      }) do
    with {:ok, realm_name} <- get_realm_name(conn),
         {:ok, realm} <- Astarte.fetch_realm_by_name(realm_name),
         :ok <- Astarte.process_device_event(realm, device_id, event, timestamp) do
      send_resp(conn, :ok, "")
    end
  end

  defp get_realm_name(conn) do
    case get_req_header(conn, "astarte-realm") do
      [realm_name] -> {:ok, realm_name}
      _ -> {:error, :missing_astarte_realm_header}
    end
  end

  # TODO: needed for backwards compatibility, delete when we drop support for OTAResponse
  defp translate_ota_response_status("InProgress"), do: "Acknowledged"
  defp translate_ota_response_status("Error"), do: "Failure"
  defp translate_ota_response_status("Done"), do: "Success"

  defp translate_ota_response_status_code(nil), do: nil
  defp translate_ota_response_status_code("OTAErrorNetwork"), do: "NetworkError"
  defp translate_ota_response_status_code("OTAErrorNvs"), do: nil
  defp translate_ota_response_status_code("OTAAlreadyInProgress"), do: "UpdateAlreadyInProgress"
  defp translate_ota_response_status_code("OTAFailed"), do: nil
  defp translate_ota_response_status_code("OTAErrorDeploy"), do: "IOError"
  defp translate_ota_response_status_code("OTAErrorBootWrongPartition"), do: "SystemRollback"
end
