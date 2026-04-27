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

defmodule Edgehog.Files.FileDownloadRequest.Changes.HandleEphemeralFileUpload do
  @moduledoc """
  Ash change responsible for handling the upload of an ephemeral file associated
  with a file download request when a file is provided in the changeset arguments.
  """

  use Ash.Resource.Change

  alias Edgehog.Files.Compressor
  alias Edgehog.Files.Digest
  alias Edgehog.Files.EphemeralFile

  @ephemeral_file_module Application.compile_env(
                           :edgehog,
                           :files_ephemeral_file_module,
                           EphemeralFile
                         )

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :file) do
      {:ok, %Plug.Upload{} = file} ->
        changeset
        |> Ash.Changeset.before_transaction(&upload_file(&1, file))
        |> Ash.Changeset.after_transaction(&cleanup_on_error(&1, &2))

      _ ->
        changeset
    end
  end

  defp upload_file(changeset, file) do
    tenant_id = changeset.to_tenant
    file_download_request_id = Ash.Changeset.get_attribute(changeset, :id)
    encoding = Ash.Changeset.get_attribute(changeset, :encoding)

    case maybe_compress_file(file, encoding) do
      {:ok, upload_file} ->
        result =
          case @ephemeral_file_module.upload(tenant_id, file_download_request_id, upload_file) do
            {:ok, file_url} ->
              changeset
              |> Ash.Changeset.force_change_attribute(:url, file_url)
              |> Ash.Changeset.force_change_attribute(
                :digest,
                Digest.file_sha256!(upload_file.path)
              )
              |> Ash.Changeset.put_context(:file_uploaded?, true)

            {:error, _reason} ->
              Ash.Changeset.add_error(changeset, field: :file, message: "failed to upload")
          end

        maybe_delete_temporary_upload(file, upload_file)
        result

      {:error, _reason} ->
        Ash.Changeset.add_error(changeset, field: :file, message: "failed to upload")
    end
  end

  defp maybe_compress_file(%Plug.Upload{} = file, encoding) when encoding in ["gz", "tar.gz"] do
    Compressor.compress(file, :gz)
  end

  defp maybe_compress_file(%Plug.Upload{} = file, encoding) when encoding in ["lz4", "tar.lz4"] do
    Compressor.compress(file, :lz4)
  end

  defp maybe_compress_file(%Plug.Upload{} = file, _encoding), do: {:ok, file}

  defp maybe_delete_temporary_upload(%Plug.Upload{path: original_path}, %Plug.Upload{path: path})
       when original_path != path do
    _ = File.rm(path)
    :ok
  end

  defp maybe_delete_temporary_upload(_original_file, _processed_file), do: :ok

  # If we've uploaded the file and the transaction resulted in an error, we do our
  # best to clean up
  defp cleanup_on_error(changeset, {:error, _} = result) do
    if changeset.context[:file_uploaded?] do
      tenant_id = changeset.to_tenant
      file_download_request_id = Ash.Changeset.get_attribute(changeset, :id)
      file_url = Ash.Changeset.get_attribute(changeset, :url)

      _ = @ephemeral_file_module.delete(tenant_id, file_download_request_id, file_url)
    end

    result
  end

  defp cleanup_on_error(_changeset, result), do: result
end
