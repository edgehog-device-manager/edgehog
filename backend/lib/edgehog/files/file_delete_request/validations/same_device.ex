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

defmodule Edgehog.Files.FileDeleteRequest.Validations.SameDevice do
  @moduledoc false

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidArgument
  alias Edgehog.Files.FileDownloadRequest

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, %{tenant: tenant} = _context) do
    device_id = Ash.Changeset.get_argument(changeset, :device_id)
    file_download_request_id = Ash.Changeset.get_argument(changeset, :file_download_request_id)

    with {:ok, file_download_request} <-
           Ash.get(FileDownloadRequest, file_download_request_id, tenant: tenant) do
      validate_request(file_download_request, device_id)
    end
  end

  # Destination is storage AND device_id matches
  defp validate_request(%{destination_type: :storage, device_id: device_id}, device_id), do: :ok

  # Destination is storage, but the device_id does not match
  defp validate_request(%{destination_type: :storage}, _device_id) do
    {:error,
     InvalidArgument.exception(
       field: :file_download_request_id,
       message: "does not belong to device"
     )}
  end

  # Destination type is not storage
  defp validate_request(_file_download_request, _device_id) do
    {:error,
     InvalidArgument.exception(
       field: :file_download_request_id,
       message: "must be storage"
     )}
  end

  @impl Ash.Resource.Validation
  def batch_callbacks?(_changeset, _opts, _context), do: false

  @impl Ash.Resource.Validation
  def has_batch_validate?, do: false
end
