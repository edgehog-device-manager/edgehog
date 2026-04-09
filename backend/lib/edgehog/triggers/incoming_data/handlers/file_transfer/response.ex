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

defmodule Edgehog.Triggers.IncomingData.Handlers.FileTransfer.Response do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Ash.Astarte.Triggers.HandlerBehavior
  alias Edgehog.Files

  @impl HandlerBehavior
  def handle_event(%{value: %{"type" => "server_to_device"}} = event, _opts, %{tenant: tenant}) do
    request_id = event.value["id"]
    response_code = event.value["code"]
    response_message = event.value["message"]

    {status, progress_percentage} =
      case response_code do
        0 -> {:completed, 100}
        _ -> {:failed, 0}
      end

    file_download_request = Files.fetch_file_download_request!(request_id, tenant: tenant)

    Files.set_response(
      file_download_request,
      [
        status: status,
        response_code: response_code,
        response_message: response_message,
        progress_percentage: progress_percentage
      ],
      tenant: tenant
    )
  end

  @impl HandlerBehavior
  def handle_event(%{value: %{"type" => "device_to_server"}} = event, _opts, %{tenant: tenant}) do
    file_upload_request_id = event.value["id"]
    response_code = event.value["code"]
    response_message = event.value["message"]

    status =
      case response_code do
        0 -> :completed
        _ -> :failed
      end

    file_upload_request = Files.fetch_file_upload_request!(file_upload_request_id, tenant: tenant)

    Files.set_file_upload_response(
      file_upload_request,
      [status: status, response_code: response_code, response_message: response_message],
      tenant: tenant
    )
  end
end
