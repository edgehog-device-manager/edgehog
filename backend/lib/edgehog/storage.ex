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

    case s3_presign_config() do
      {:s3, config} -> s3_aws_gen_presigned_urls(config, [:get, :put], bucket, file_path)
      {:gcs, client} -> s3_gcs_gen_presigned_urls(client, [:get, :put], bucket, file_path)
    end
  end

  defp s3_read_presigned_url(file_path) do
    bucket = bucket!()

    case s3_presign_config() do
      {:s3, config} -> s3_aws_gen_presigned_urls(config, [:get], bucket, file_path)
      {:gcs, client} -> s3_gcs_gen_presigned_urls(client, [:get], bucket, file_path)
    end
  end

  defp s3_aws_gen_presigned_urls(config, verbs, bucket, file_path) do
    results =
      verbs
      |> Enum.map(&gen_aws_signed_url(config, bucket, file_path, &1))
      |> Enum.split_with(&match?({:error, _}, &1))

    case results do
      {[], result} -> {:ok, Enum.into(result, %{})}
      {errors, _} -> {:error, extract_errors(errors)}
    end
  end

  defp s3_gcs_gen_presigned_urls(client, verbs, bucket, file_path) do
    results =
      verbs
      |> Enum.map(&gen_gcs_signed_url(client, bucket, file_path, &1))
      |> Enum.split_with(&match?({:error, _}, &1))

    case results do
      {[], result} -> {:ok, Enum.into(result, %{})}
      {errors, _} -> {:error, extract_errors(errors)}
    end
  end

  defp gen_aws_signed_url(config, bucket, file_path, verb) do
    # We're not generating an uncontrolled amount of atoms. At most 2: :get_url
    # and :put_url. This should be fine.

    # credo:disable-for-next-line
    key = :"#{verb}_url"

    with {:ok, url} <-
           ExAws.S3.presigned_url(config, verb, bucket, file_path,
             expires_in: @presign_expiration_seconds
           ) do
      {key, url}
    end
  end

  defp gen_gcs_signed_url(client, bucket, file_path, verb) do
    # We're not generating an uncontrolled amount of atoms. At most 2: :get_url
    # and :put_url. This should be fine.

    # credo:disable-for-next-line
    key = :"#{verb}_url"

    verb = verb |> to_string |> String.upcase()

    url =
      GcsSignedUrl.generate_v4(client, bucket, file_path,
        expires: @presign_expiration_seconds,
        verb: verb
      )

    {key, url}
  end

  defp extract_errors(errors) do
    Enum.map(errors, fn {:error, error} -> error end)
  end

  # Builds an ExAws S3 config that points to the *external* (public) S3 host so
  # that presigned URLs are reachable by clients outside the cluster.
  defp s3_presign_config do
    overrides = Application.get_env(:edgehog, :s3_presign_host_config, %{})
    host = Map.get(overrides, :host)

    # S3 does not play well with Google storage service, hence if the host is
    # google we need an ad-hoc service to create urls.
    case host do
      "storage.googleapis.com" -> {:gcs, gcs_client()}
      _ -> {:s3, s3_config(overrides)}
    end
  end

  defp s3_config(overrides) do
    :s3
    |> ExAws.Config.new()
    |> Map.merge(overrides)
  end

  defp gcs_client do
    # If `:s3_presign_host_config` has a `storage.googleapis.com` host, then
    # goth is enabled, and `gcp_credentials` should be provided. In this case we
    # can assume the environment `gcp_credentials` is filled.
    :goth
    |> Application.get_env(:gcp_credentials)
    |> Jason.decode!()
    |> GcsSignedUrl.Client.load()
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
