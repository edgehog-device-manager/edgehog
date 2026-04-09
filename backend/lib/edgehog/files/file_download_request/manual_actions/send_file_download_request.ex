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

defmodule Edgehog.Files.FileDownloadRequest.ManualActions.SendFileDownloadRequest do
  @moduledoc """
  Manual action responsible for sending a file download request to the Astarte device.
  """

  use Ash.Resource.Actions.Implementation

  alias Edgehog.Astarte.Device
  alias Edgehog.Astarte.Device.FileDownloadRequest.RequestData
  alias Edgehog.Error.AstarteAPIError
  alias Edgehog.Files

  @interface "io.edgehog.devicemanager.fileTransfer.ServerToDevice"

  @file_download_request_module Application.compile_env(
                                  :edgehog,
                                  :astarte_file_download_request_module,
                                  Device.FileDownloadRequest
                                )

  @impl Ash.Resource.Actions.Implementation
  def run(input, _opts, %{tenant: tenant} = _context) do
    file_download_request =
      Ash.load!(
        input.arguments.file_download_request,
        [:url, device: [:device_id, :appengine_client]],
        reuse_values?: true
      )

    %{
      id: file_download_request_id,
      url: url,
      device: %{
        device_id: device_id,
        appengine_client: client
      }
    } = file_download_request

    # TODO: HTTP headers reserved for future bucket auth support.
    # Currently unused (set to empty arrays), flow/config (env vs request) TBD.
    request_data = %RequestData{
      id: file_download_request_id,
      url: url,
      httpHeaderKeys: [],
      httpHeaderValues: [],
      encoding: file_download_request.encoding || "",
      fileSizeBytes: file_download_request.uncompressed_file_size_bytes,
      progress: file_download_request.progress_tracked,
      digest: file_download_request.digest,
      ttlSeconds: file_download_request.ttl_seconds,
      fileMode: file_download_request.file_mode || 0,
      userId: file_download_request.user_id || -1,
      groupId: file_download_request.group_id || -1,
      destinationType: file_download_request.destination_type,
      destination: file_download_request.destination || ""
    }

    case @file_download_request_module.request_download(
           client,
           device_id,
           request_data
         ) do
      {:error, %Astarte.Client.APIError{} = api_error} ->
        reason =
          AstarteAPIError.exception(
            status: api_error.status,
            response: api_error.response,
            device_id: device_id,
            interface: @interface
          )

        {:error, reason}

      {:error, reason} ->
        {:error, reason}

      result ->
        Files.set_status(file_download_request, %{status: :sent}, tenant: tenant)

        result
    end
  end
end
