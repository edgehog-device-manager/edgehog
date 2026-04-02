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

defmodule Edgehog.Storage do
  @moduledoc """
  Storage-agnostic presigned URL generation and file management.

  Dispatches to S3 or Azure backend based on the configured `:storage_type`.
  """
  @behaviour Edgehog.Storage.Behaviour

  alias Azurex.Blob.SharedAccessSignature

  @presign_expiration_seconds 3600

  @doc """
  Generates presigned GET and PUT URLs for a given file path.

  Returns `{:ok, %{get_url: url, put_url: url}}`.
  """
  @impl Edgehog.Storage.Behaviour
  def create_presigned_urls(file_path) do
    case storage_type() do
      :s3 -> s3_create_presigned_urls(file_path)
      :azure -> azure_create_presigned_urls(file_path)
    end
  end

  @doc """
  Generates a presigned GET URL for a given file path.

  Returns `{:ok, %{get_url: url}}`.
  """
  @impl Edgehog.Storage.Behaviour
  def read_presigned_url(file_path) do
    case storage_type() do
      :s3 -> s3_read_presigned_url(file_path)
      :azure -> azure_read_presigned_url(file_path)
    end
  end

  @doc """
  Deletes a file at the given path from the configured storage backend.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @impl Edgehog.Storage.Behaviour
  def delete(file_path) do
    case storage_type() do
      :s3 -> s3_delete(file_path)
      :azure -> azure_delete(file_path)
    end
  end

  @doc """
  Returns the configured storage bucket/container name.
  """
  def bucket! do
    Application.fetch_env!(:edgehog, :storage_bucket)
  end

  defp storage_type do
    Application.fetch_env!(:edgehog, :storage_type)
  end

  # --- S3 backend ---

  defp s3_create_presigned_urls(file_path) do
    bucket = bucket!()
    config = s3_presign_config()

    with {:ok, get_url} <-
           ExAws.S3.presigned_url(config, :get, bucket, file_path,
             expires_in: @presign_expiration_seconds
           ),
         {:ok, put_url} <-
           ExAws.S3.presigned_url(config, :put, bucket, file_path,
             expires_in: @presign_expiration_seconds
           ) do
      {:ok, %{get_url: get_url, put_url: put_url}}
    end
  end

  defp s3_read_presigned_url(file_path) do
    bucket = bucket!()
    config = s3_presign_config()

    with {:ok, get_url} <-
           ExAws.S3.presigned_url(config, :get, bucket, file_path,
             expires_in: @presign_expiration_seconds
           ) do
      {:ok, %{get_url: get_url}}
    end
  end

  # Builds an ExAws S3 config that points to the *external* (public) S3 host so
  # that presigned URLs are reachable by clients outside the cluster.
  defp s3_presign_config do
    overrides = Application.get_env(:edgehog, :s3_presign_host_config, %{})

    :s3
    |> ExAws.Config.new()
    |> Map.merge(overrides)
  end

  defp s3_delete(file_path) do
    bucket = bucket!()

    result =
      bucket
      |> ExAws.S3.delete_object(file_path)
      |> ExAws.request()

    case result do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Azure backend ---

  defp azure_create_presigned_urls(file_path) do
    container = bucket!()
    encoded_path = uri_encode_path(file_path)

    get_url =
      SharedAccessSignature.sas_url(container, encoded_path,
        resource_type: :blob,
        permissions: [:read],
        expiry: {:second, @presign_expiration_seconds}
      )

    put_url =
      SharedAccessSignature.sas_url(container, encoded_path,
        resource_type: :blob,
        permissions: [:create, :write],
        expiry: {:second, @presign_expiration_seconds}
      )

    {:ok, %{get_url: get_url, put_url: put_url}}
  end

  defp azure_read_presigned_url(file_path) do
    container = bucket!()
    encoded_path = uri_encode_path(file_path)

    get_url =
      SharedAccessSignature.sas_url(container, encoded_path,
        resource_type: :blob,
        permissions: [:read],
        expiry: {:second, @presign_expiration_seconds}
      )

    {:ok, %{get_url: get_url}}
  end

  defp azure_delete(file_path) do
    container = bucket!()

    Azurex.Blob.delete_blob(file_path, container)
  end

  # URI-encodes each segment of a file path, preserving "/" separators.
  defp uri_encode_path(path) do
    path
    |> String.split("/")
    |> Enum.map_join("/", &URI.encode/1)
  end
end
