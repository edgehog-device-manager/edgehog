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

defmodule Edgehog.Files.FileDownloadRequest.Validations.ValidateDestination do
  @moduledoc """
  Validates the destination + destination type argument combo.

  - when storage the destination is ignored. The file name will be used anyways.
  - when streaming  the destination must be empty
  - when filesystem, the destination must be filled.
  """

  use Ash.Resource.Validation

  @no_dest_filesystem "is required when destination_type is filesystem"

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    destination_type = Ash.Changeset.get_attribute(changeset, :destination_type)
    destination = Ash.Changeset.get_attribute(changeset, :destination)

    case {destination_type, destination} do
      {:storage, _} ->
        # Destination is ignored for storage: the file name is sent instead.
        :ok

      {:streaming, nil} ->
        :ok

      {:streaming, ""} ->
        :ok

      {:streaming, _} ->
        {:error, field: :destination, message: "must be empty when destination_type is streaming"}

      {:filesystem, nil} ->
        {:error, field: :destination, message: @no_dest_filesystem}

      {:filesystem, dest} ->
        if String.trim(dest) != "" do
          :ok
        else
          {:error, field: :destination, message: @no_dest_filesystem}
        end
    end
  end
end
