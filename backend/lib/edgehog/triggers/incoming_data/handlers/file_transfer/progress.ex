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

defmodule Edgehog.Triggers.IncomingData.Handlers.FileTransfer.Progress do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Ash.Astarte.Triggers.HandlerBehavior
  alias Edgehog.Files
  alias Edgehog.Files.FileDownloadRequest
  alias Edgehog.Files.FileUploadRequest

  @impl HandlerBehavior
  def handle_event(%{value: %{"type" => "server_to_device"}} = event, _opts, %{tenant: tenant}) do
    request_id = event.value["id"]
    progress = derive_progress(event.value)

    file_download_request = Files.fetch_file_download_request!(request_id, tenant: tenant)

    update_progress_and_status(file_download_request, progress, tenant)
  end

  @impl HandlerBehavior
  def handle_event(%{value: %{"type" => "device_to_server"}} = event, _opts, %{tenant: tenant}) do
    file_upload_request_id = event.value["id"]
    progress = derive_progress(event.value)

    file_upload_request = Files.fetch_file_upload_request!(file_upload_request_id, tenant: tenant)

    update_progress_and_status(file_upload_request, progress, tenant)
  end

  defp update_progress_and_status(%{status: status} = request, progress, tenant)
       when status in [:sent, :in_progress] do
    update_with_progress(request, progress, tenant)
  end

  defp update_progress_and_status(request, _progress, _tenant), do: {:ok, request}

  defp update_with_progress(
         %FileDownloadRequest{} = file_download_request,
         {:percentage, percentage},
         tenant
       ) do
    if percentage in 0..99 do
      Files.set_file_download_progress(
        file_download_request,
        [progress_percentage: percentage, status: :in_progress],
        tenant: tenant
      )
    else
      {:ok, file_download_request}
    end
  end

  defp update_with_progress(
         %FileDownloadRequest{} = file_download_request,
         :unknown_total,
         tenant
       ) do
    Files.set_file_download_progress(
      file_download_request,
      [status: :in_progress],
      tenant: tenant
    )
  end

  defp update_with_progress(
         %FileUploadRequest{} = file_upload_request,
         {:percentage, percentage},
         tenant
       ) do
    cond do
      percentage in 0..99 ->
        Files.set_file_upload_progress(
          file_upload_request,
          [progress_percentage: percentage, status: :in_progress],
          tenant: tenant
        )

      percentage >= 100 ->
        Files.set_file_upload_progress(
          file_upload_request,
          [progress_percentage: 100, status: :completed],
          tenant: tenant
        )
    end
  end

  defp update_with_progress(%FileUploadRequest{} = file_upload_request, :unknown_total, tenant) do
    Files.set_file_upload_progress(
      file_upload_request,
      [status: :in_progress],
      tenant: tenant
    )
  end

  defp derive_progress(%{"bytes" => bytes, "totalBytes" => -1})
       when is_integer(bytes) and bytes >= 0, do: :unknown_total

  defp derive_progress(%{"bytes" => bytes, "totalBytes" => 0})
       when is_integer(bytes) and bytes >= 0, do: {:percentage, 100}

  defp derive_progress(%{"bytes" => bytes, "totalBytes" => total_bytes}) do
    percentage =
      bytes
      |> Kernel.*(100)
      |> div(total_bytes)
      |> max(0)
      |> min(100)

    {:percentage, percentage}
  end
end
