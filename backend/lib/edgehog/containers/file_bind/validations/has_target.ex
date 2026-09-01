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

defmodule Edgehog.Containers.FileBind.Validations.HasTarget do
  @moduledoc false
  use Ash.Resource.Validation

  alias Ash.Resource.Validation

  @impl Validation
  def validate(changeset, _opts, _context) do
    file_request_id = Ash.Changeset.fetch_argument(changeset, :file_download_request_id)
    device_file_id = Ash.Changeset.fetch_argument(changeset, :device_file_id)

    case {file_request_id, device_file_id} do
      {{:ok, _}, {:ok, _}} ->
        {:error,
         message:
           "Ambiguous file bind setting. either use a file download request id or a device file id."}

      {:error, :error} ->
        {:error,
         message:
           "The file bind needs a file target. either set a file download request id or a device file id."}

      _ ->
        :ok
    end
  end
end
