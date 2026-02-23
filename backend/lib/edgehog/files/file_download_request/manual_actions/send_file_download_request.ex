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

  @file_download_request_module Application.compile_env(
                                  :edgehog,
                                  :astarte_file_download_request_module,
                                  Device.FileDownloadRequest
                                )

  @impl Ash.Resource.Actions.Implementation
  def run(input, _opts, _context) do
    %{
      id: file_download_request_id,
      url: url,
      device: %{
        device_id: device_id,
        appengine_client: client
      }
    } =
      Ash.load!(
        input.arguments.file_download_request,
        [:url, device: [:device_id, :appengine_client]],
        reuse_values?: true
      )

    # TODO: HTTP headers (key/value) reserved for future bucket auth support.
    # Currently unused (set to ""), flow/config (env vs request) TBD.
    request_data = %RequestData{
      id: file_download_request_id,
      url: url,
      httpHeaderKey: "",
      httpHeaderValue: "",
      compression: input.arguments.file_download_request.compression || "",
      fileSizeBytes: input.arguments.file_download_request.uncompressed_file_size_bytes,
      progress: input.arguments.file_download_request.progress,
      digest: input.arguments.file_download_request.digest,
      fileName: input.arguments.file_download_request.file_name,
      ttlSeconds: input.arguments.file_download_request.ttl_seconds,
      fileMode: input.arguments.file_download_request.file_mode,
      userId: input.arguments.file_download_request.user_id,
      groupId: input.arguments.file_download_request.group_id,
      destination: input.arguments.file_download_request.destination
    }

    with {:error, %Astarte.Client.APIError{} = api_error} <-
           @file_download_request_module.request_download(
             client,
             device_id,
             request_data
           ) do
      reason =
        AstarteAPIError.exception(
          status: api_error.status,
          response: api_error.response
        )

      {:error, reason}
    end
  end
end
