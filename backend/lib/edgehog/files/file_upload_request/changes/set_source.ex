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

defmodule Edgehog.Files.FileUploadRequest.Changes.SetSource do
  @moduledoc """
  Changes module responsible for deriving and setting the `source` attribute
  of a `FileUploadRequest` based on its `source_type`.
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Ash.Error.Changes.InvalidArgument

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    source_type = Changeset.get_attribute(changeset, :source_type)

    set_source_based_on_type(changeset, source_type)
  end

  defp set_source_based_on_type(changeset, :filesystem) do
    case Changeset.get_argument(changeset, :file_system_path) do
      nil ->
        Changeset.add_error(
          changeset,
          "is required when source_type is :filesystem",
          :file_system_path
        )

      path ->
        Changeset.change_attribute(changeset, :source, path)
    end
  end

  defp set_source_based_on_type(changeset, :storage) do
    case Changeset.get_argument(changeset, :device_file_id) do
      nil ->
        Changeset.add_error(
          changeset,
          "is required when source_type is :storage",
          :device_file_id
        )

      device_file_id ->
        fetch_and_set_device_file(changeset, device_file_id)
    end
  end

  defp set_source_based_on_type(changeset, _invalid_type) do
    error =
      InvalidArgument.exception(
        field: :source_type,
        message: "Invalid source_type. Must be either :storage or :filesystem."
      )

    Changeset.add_error(changeset, error)
  end

  defp fetch_and_set_device_file(changeset, device_file_id) do
    tenant = changeset.tenant

    case Edgehog.Files.fetch_device_file(device_file_id, tenant: tenant) do
      {:ok, device_file} ->
        Changeset.change_attribute(changeset, :source, device_file.file_id)

      {:error, reason} ->
        Changeset.add_error(changeset, reason)
    end
  end
end
