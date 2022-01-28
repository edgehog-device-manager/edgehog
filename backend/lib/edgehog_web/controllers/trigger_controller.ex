#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule EdgehogWeb.AstarteTriggerController do
  use EdgehogWeb, :controller

  alias Edgehog.Astarte
  alias Edgehog.OSManagement

  require Logger

  @ota_response_interface "io.edgehog.devicemanager.OTAResponse"

  # TODO: split incoming triggers with a dedicated shunt so we can route them in a clearer way
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
      "status" => status,
      "statusCode" => status_code
    } = value

    ota_operation = OSManagement.get_ota_operation!(uuid)
    attrs = %{status: status, status_code: status_code}

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
end
