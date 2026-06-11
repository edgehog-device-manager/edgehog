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

defmodule Edgehog.Files.FileDeleteRequest.ManualActions.SendFileDeleteRequest do
  @moduledoc """
  Manual action responsible for sending a file download request to the Astarte device.
  """

  use Ash.Resource.Actions.Implementation

  alias Edgehog.Astarte.Device
  alias Edgehog.Astarte.Device.FileDeleteRequest.RequestData
  alias Edgehog.Error.AstarteAPIError
  alias Edgehog.Files

  @interface "io.edgehog.devicemanager.storage.DeleteFile"

  @file_delete_request_module Application.compile_env(
                                :edgehog,
                                :astarte_file_delete_request_module,
                                Device.FileDeleteRequest
                              )

  @impl Ash.Resource.Actions.Implementation
  def run(input, _opts, %{tenant: tenant} = _context) do
    file_delete_request =
      Ash.load!(
        input.arguments.file_delete_request,
        [:device_file, device: [:device_id, :appengine_client]],
        reuse_values?: true
      )

    %{
      id: file_delete_request_id,
      device_file: %{file_id: file_id},
      force: force,
      device: %{
        device_id: device_id,
        appengine_client: client
      }
    } = file_delete_request

    request_data = %RequestData{
      id: file_delete_request_id,
      fileId: file_id,
      force: force
    }

    case @file_delete_request_module.request_deletion(
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
        Files.set_file_deletion_status(file_delete_request, %{status: :sent}, tenant: tenant)

        result
    end
  end
end
