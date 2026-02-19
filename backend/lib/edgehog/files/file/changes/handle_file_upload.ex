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

defmodule Edgehog.Files.File.Changes.HandleFileUpload do
  @moduledoc """
  Ash change to handle file upload before a file record is created or updated.
  Calculates file size and digest for data integrity.
  """

  use Ash.Resource.Change

  alias Edgehog.Files.File.BucketStorage

  require Logger

  @storage_module Application.compile_env(
                    :edgehog,
                    :files_storage_module,
                    BucketStorage
                  )

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :file) do
      {:ok, %Plug.Upload{} = file} ->
        changeset
        |> Ash.Changeset.before_transaction(&upload_and_enrich_file(&1, file))
        |> Ash.Changeset.after_transaction(&cleanup_on_error(&1, &2))

      _ ->
        changeset
    end
  end

  defp upload_and_enrich_file(changeset, file) do
    tenant_id = changeset.to_tenant
    {:ok, file_name} = Ash.Changeset.fetch_change(changeset, :name)

    {:ok, repository_id} =
      Ash.Changeset.fetch_argument(changeset, :repository_id)

    %File.Stat{size: file_size} = File.stat!(file.path)

    digest = calculate_digest(file.path)

    case @storage_module.store(tenant_id, file_name, repository_id, file) do
      {:ok, file_url} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:url, file_url)
        |> Ash.Changeset.force_change_attribute(:size, file_size)
        |> Ash.Changeset.force_change_attribute(:digest, digest)
        |> Ash.Changeset.put_context(:file_uploaded?, true)

      {:error, reason} ->
        Logger.error("Failed to upload file #{file_name}: #{inspect(reason)}")
        Ash.Changeset.add_error(changeset, field: :file, message: "failed to upload")
    end
  end

  # Streams the file into Erlang's crypto module to generate the SHA256 string
  defp calculate_digest(file_path) do
    hash =
      file_path
      |> File.stream!(2048)
      |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    "sha256:#{hash}"
  end

  # If we've uploaded the file and the transaction resulted in an error, we do our
  # best to clean up
  defp cleanup_on_error(%{context: %{file_uploaded?: true}} = changeset, {:error, _} = result) do
    case Ash.Changeset.apply_attributes(changeset) do
      {:ok, file} ->
        _ = @storage_module.delete(file)

      {:error, reason} ->
        Logger.warning("Failed to apply attributes for cleanup: #{inspect(reason)}")
    end

    result
  end

  defp cleanup_on_error(_changeset, result), do: result
end
