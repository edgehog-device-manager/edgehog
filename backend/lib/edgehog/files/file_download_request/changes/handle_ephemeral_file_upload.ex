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
    file_name = file.filename
    digest = calculate_digest(file.path)

    %File.Stat{size: file_size, mode: file_mode, uid: user_id, gid: group_id} =
      File.stat!(file.path)

    case @ephemeral_file_module.upload(tenant_id, file_download_request_id, file) do
      {:ok, file_url} ->
        changeset
        |> Ash.Changeset.change_attribute(:url, file_url)
        |> Ash.Changeset.change_attribute(:file_name, file_name)
        |> Ash.Changeset.change_attribute(:uncompressed_file_size_bytes, file_size)
        |> Ash.Changeset.change_attribute(:file_mode, file_mode)
        |> Ash.Changeset.change_attribute(:user_id, user_id)
        |> Ash.Changeset.change_attribute(:group_id, group_id)
        |> Ash.Changeset.change_attribute(:digest, digest)
        |> Ash.Changeset.put_context(:file_uploaded?, true)

      {:error, _reason} ->
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
