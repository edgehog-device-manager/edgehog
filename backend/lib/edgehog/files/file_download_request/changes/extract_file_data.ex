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

defmodule Edgehog.Files.FileDownloadRequest.Changes.ExtractFileData do
  @moduledoc false

  use Ash.Resource.Change

  alias Edgehog.Devices.Device
  alias Edgehog.Files.File

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant} = _context) do
    file_id = Ash.Changeset.get_argument(changeset, :file_id)
    file = Ash.get!(File, file_id, tenant: tenant)

    device_id = Ash.Changeset.get_argument(changeset, :device_id)

    device_file_transfer_capabilities =
      Device
      |> Ash.get!(device_id, tenant: tenant)
      |> Ash.load!(:file_transfer_capabilities)
      |> Map.get(:file_transfer_capabilities)

    case choose_url_and_encoding(file, device_file_transfer_capabilities) do
      {:error, message} ->
        Ash.Changeset.add_error(changeset,
          field: :device_id,
          message: message
        )

      {:ok, file_url, encoding, digest} ->
        changeset
        |> Ash.Changeset.change_attribute(:file_name, file.name)
        |> Ash.Changeset.change_attribute(:uncompressed_file_size_bytes, file.size)
        |> Ash.Changeset.change_attribute(:digest, digest)
        |> Ash.Changeset.change_attribute(:url, file_url)
        |> Ash.Changeset.change_attribute(:encoding, encoding)
    end
  end

  defp choose_url_and_encoding(%{is_archive: true} = file, %{encodings: encodings}) do
    cond do
      "tar.gz" in encodings ->
        {:ok, file.gz_file.url, "tar.gz", file.gz_file.digest}

      "tar.lz4" in encodings ->
        {:ok, file.lz4_file.url, "tar.lz4", file.lz4_file.digest}

      "tar" in encodings ->
        {:ok, file.base_file.url, "tar", file.base_file.digest}

      true ->
        {:error, "Device does not support archives"}
    end
  end

  defp choose_url_and_encoding(%{is_archive: false} = file, %{encodings: encodings}) do
    cond do
      "gz" in encodings ->
        {:ok, file.gz_file.url, "gz", file.gz_file.digest}

      "lz4" in encodings ->
        {:ok, file.lz4_file.url, "lz4", file.lz4_file.digest}

      true ->
        {:ok, file.base_file.url, "", file.base_file.digest}
    end
  end
end
