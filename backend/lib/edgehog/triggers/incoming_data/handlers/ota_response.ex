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

defmodule Edgehog.Triggers.IncomingData.Handlers.OTAResponse do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.OSManagement

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, %{tenant: tenant}) do
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
