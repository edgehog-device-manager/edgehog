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

defmodule Edgehog.Files.File.Changes.SetIsArchive do
  @moduledoc false

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :file) do
      {:ok, %Plug.Upload{} = file} ->
        cond do
          ustar?(file.path) ->
            Ash.Changeset.change_attribute(changeset, :is_archive, true)

          archive?(file.path) ->
            Ash.Changeset.add_error(changeset,
              field: :file,
              message: "Only USTAR tar archives are supported"
            )

          true ->
            Ash.Changeset.change_attribute(changeset, :is_archive, false)
        end

      _ ->
        changeset
    end
  end

  def ustar?(path) do
    case pread(path, 257, 5) do
      {:ok, "ustar"} ->
        true

      _ ->
        false
    end
  end

  def archive?(path) do
    case pread(path, 0, 7) do
      # ZIP
      {:ok, <<0x50, 0x4B, _::binary>>} -> true
      # RAR
      {:ok, <<0x52, 0x61, 0x72, 0x21, _::binary>>} -> true
      # 7z
      {:ok, <<0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, _::binary>>} -> true
      _ -> false
    end
  end

  defp pread(path, offset, size) do
    case :file.open(path, [:read, :binary, :raw]) do
      {:ok, io_device} ->
        try do
          case :file.pread(io_device, offset, size) do
            {:ok, data} -> {:ok, data}
            :eof -> {:ok, <<>>}
            {:error, _reason} = error -> error
          end
        after
          :ok = :file.close(io_device)
        end

      {:error, _reason} = error ->
        error
    end
  end
end
