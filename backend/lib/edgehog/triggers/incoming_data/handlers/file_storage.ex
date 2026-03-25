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

defmodule Edgehog.Triggers.IncomingData.Handlers.FileStorage do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Files

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, %{tenant: tenant}) do
    case String.split(event.path, "/") do
      ["", request_id, "pathOnDevice"] ->
        file_download_request = Files.fetch_file_download_request!(request_id, tenant: tenant)

        Files.set_path_on_device(file_download_request, event.value, tenant: tenant)

      ["", request_id, "sizeBytes"] ->
        file_download_request = Files.fetch_file_download_request!(request_id, tenant: tenant)

        Files.set_size_bytes(file_download_request, event.value, tenant: tenant)

      _ ->
        {:error, :invalid_event_path}
    end
  end
end
