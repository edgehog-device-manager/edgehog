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
  """

  use Ash.Resource.Change

  alias Edgehog.Files.Compressor
  alias Edgehog.Files.Digest
  alias Edgehog.Files.File.BucketStorage

  require Logger

  @storage_module Application.compile_env(:edgehog, :files_storage_module, BucketStorage)

  @encodings [nil, :gz, :lz4]
  @minute_ms 60_000
  @bytes_per_gb 1_073_741_824

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :file) do
      {:ok, %Plug.Upload{} = file} ->
        changeset
        |> Ash.Changeset.before_transaction(&process_uploads(&1, file))
        |> Ash.Changeset.after_transaction(&cleanup_on_error(&1, &2))

      _ ->
        changeset
    end
  end

  defp process_uploads(changeset, file) do
    {:ok, file_name} = Ash.Changeset.fetch_change(changeset, :name)
    {:ok, repository_id} = Ash.Changeset.fetch_argument(changeset, :repository_id)

    file = %{file | filename: file_name}

    timeout = upload_timeout_ms(file)

    uploads =
      Enum.map(@encodings, fn encoding ->
        {encoding,
         Task.async(fn ->
           encode_and_upload_file(changeset, file_name, repository_id, file, encoding)
         end)}
      end)

    tasks = Enum.map(uploads, fn {_encoding, task} -> task end)
    results = Task.yield_many(tasks, timeout)

    {changeset, failed?} =
      uploads
      |> Enum.zip(results)
      |> Enum.reduce({changeset, false}, &reduce_results/2)

    if failed? do
      Ash.Changeset.add_error(changeset,
        field: :file,
        message: "One or more file uploads failed"
      )
    else
      changeset
    end
  end

  defp encode_and_upload_file(changeset, file_name, repo_id, file, encoding) do
    case maybe_compress(file, encoding) do
      {:ok, encoded_file} ->
        result = do_file_upload(changeset, file_name, repo_id, encoding, encoded_file)
        maybe_delete_temporary_upload(file, encoded_file)

        result

      {:error, reason} ->
        Logger.error("Failed to compress #{encoding || "base"} file: #{inspect(reason)}")

        {:error,
         Ash.Changeset.add_error(changeset,
           field: :file,
           message: "Compression failed for #{encoding} file"
         )}
    end
  end

  defp do_file_upload(changeset, file_name, repo_id, encoding, encoded_file) do
    tenant_id = changeset.to_tenant

    case @storage_module.store(tenant_id, file_name, repo_id, encoding, encoded_file) do
      {:ok, url} ->
        {attr, context_key} = select_file_encoding_context(encoding)

        {:ok,
         changeset
         |> Ash.Changeset.force_change_attribute(attr, %{
           url: url,
           digest: Digest.file_sha256!(encoded_file.path)
         })
         |> Ash.Changeset.put_context(context_key, true)}

      {:error, reason} ->
        Logger.error("Failed to upload #{encoding || "base"} file: #{inspect(reason)}")

        {:error,
         Ash.Changeset.add_error(changeset,
           field: :file,
           message: "Upload failed for #{encoding || "base"} file"
         )}
    end
  end

  defp maybe_compress(file, nil), do: {:ok, file}
  defp maybe_compress(file, encoding), do: Compressor.compress(file, encoding)

  defp select_file_encoding_context(encoding) do
    case encoding do
      nil -> {:base_file, :base_file_uploaded?}
      :gz -> {:gz_file, :gz_file_uploaded?}
      :lz4 -> {:lz4_file, :lz4_file_uploaded?}
    end
  end

  defp upload_timeout_ms(%Plug.Upload{path: path}) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} when size > 0 ->
        max(ceil_div(size * @minute_ms, @bytes_per_gb), @minute_ms)

      {:ok, _stat} ->
        @minute_ms

      {:error, reason} ->
        Logger.warning(
          "Failed to read upload file size for timeout calculation: #{inspect(reason)}"
        )

        @minute_ms
    end
  end

  defp ceil_div(dividend, divisor), do: div(dividend + divisor - 1, divisor)

  defp reduce_results({{_encoding, _task}, {_task_pid, {:ok, result}}}, {acc_changeset, failed?}) do
    case result do
      {:ok, changeset} -> {merge_changesets(acc_changeset, changeset), failed?}
      {:error, changeset} -> {merge_changesets(acc_changeset, changeset), true}
    end
  end

  defp reduce_results({{encoding, task}, {_task_pid, nil}}, {acc_changeset, _failed?}) do
    Logger.error("Upload task timed out for #{encoding || "base"} encoding")
    _ = Task.shutdown(task, :brutal_kill)

    {Ash.Changeset.add_error(acc_changeset,
       field: :file,
       message: "Upload process timed out"
     ), true}
  end

  defp reduce_results(
         {{encoding, _task}, {_task_pid, {:exit, reason}}},
         {acc_changeset, _failed?}
       ) do
    Logger.error("Upload task crashed for #{encoding || "base"} encoding: #{inspect(reason)}")

    {Ash.Changeset.add_error(acc_changeset, field: :file, message: "Upload process failed"), true}
  end

  defp reduce_results({{encoding, _task}, {_task_result, reason}}, {acc_changeset, _failed?}) do
    Logger.error("Upload task failed for #{encoding || "base"} encoding: #{inspect(reason)}")

    {Ash.Changeset.add_error(acc_changeset, field: :file, message: "Upload process failed"), true}
  end

  defp merge_changesets(acc_changeset, new_changeset) do
    acc_changeset
    |> Map.put(:attributes, Map.merge(acc_changeset.attributes, new_changeset.attributes))
    |> Map.put(:context, Map.merge(acc_changeset.context, new_changeset.context))
  end

  defp maybe_delete_temporary_upload(%Plug.Upload{path: original_path}, %Plug.Upload{path: path})
       when original_path != path do
    _ = File.rm(path)
    :ok
  end

  defp maybe_delete_temporary_upload(_original_file, _processed_file), do: :ok

  # If we've uploaded the file and the transaction resulted in an error, we do our
  # best to clean up
  defp cleanup_on_error(changeset, {:error, _} = result) do
    case Ash.Changeset.apply_attributes(changeset) do
      {:ok, file_record} ->
        do_cleanup(file_record, changeset.context)

      {:error, reason} ->
        Logger.warning("Failed to apply attributes for cleanup: #{inspect(reason)}")
    end

    result
  end

  defp cleanup_on_error(_changeset, result), do: result

  defp do_cleanup(file_record, context) do
    Enum.each(@encodings, fn encoding ->
      {_, key} = select_file_encoding_context(encoding)
      if context[key], do: @storage_module.delete(file_record, encoding)
    end)
  end
end
