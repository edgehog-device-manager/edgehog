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

defmodule Edgehog.Files.FileUploadRequest.ManualActions.SendFileUploadRequest do
  @moduledoc """
  Manual action responsible for sending a file upload request to the Astarte device.
  """

  use Ash.Resource.Actions.Implementation

  alias Edgehog.Astarte.Device
  alias Edgehog.Astarte.Device.FileUploadRequest.RequestData
  alias Edgehog.Error.AstarteAPIError
  alias Edgehog.Files

  @file_upload_request_module Application.compile_env(
                                :edgehog,
                                :astarte_file_upload_request_module,
                                Device.FileUploadRequest
                              )

  @impl Ash.Resource.Actions.Implementation
  def run(input, _opts, %{tenant: tenant} = _context) do
    file_upload_request =
      Ash.load!(
        input.arguments.file_upload_request,
        [:url, device: [:device_id, :appengine_client]],
        reuse_values?: true
      )

    %{
      id: file_upload_request_id,
      url: url,
      device: %{
        device_id: device_id,
        appengine_client: client
      }
    } = file_upload_request

    request_data = %RequestData{
      id: file_upload_request_id,
      url: url,
      httpHeaderKey: "x-ms-blob-type",
      httpHeaderValue: "BlockBlob",
      compression: file_upload_request.compression || "",
      progress: file_upload_request.progress_tracked,
      source: file_upload_request.source || "",
      sourceType: file_upload_request.source_type
    }

    case @file_upload_request_module.request_upload(
           client,
           device_id,
           request_data
         ) do
      {:error, %Astarte.Client.APIError{} = api_error} ->
        reason =
          AstarteAPIError.exception(
            status: api_error.status,
            response: api_error.response
          )

        {:error, reason}

      result ->
        Files.set_file_upload_request_status(file_upload_request, %{status: :sent},
          tenant: tenant
        )

        result
    end
  end
end
