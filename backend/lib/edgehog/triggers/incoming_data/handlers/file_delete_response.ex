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

defmodule Edgehog.Triggers.IncomingData.Handlers.FileDeleteResponse do
  @moduledoc """
  File delete response handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Ash.Astarte.Triggers.HandlerBehavior
  alias Edgehog.Files

  @impl HandlerBehavior
  def handle_event(event, _opts, %{tenant: tenant}) do
    request_id = event.value["id"]
    response_code = event.value["code"]
    response_messages = event.value["messages"]

    file_delete_request =
      Files.fetch_file_delete_request!(request_id, tenant: tenant, load: :file_download_request)

    status =
      case response_code do
        0 ->
          Files.set_file_download_deleted_attribute(file_delete_request.file_download_request,
            tenant: tenant
          )

          :completed

        _ ->
          :failed
      end

    Files.set_file_delete_response(
      file_delete_request,
      [
        status: status,
        response_code: response_code,
        response_messages: response_messages
      ],
      tenant: tenant
    )
  end
end
