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

defmodule Edgehog.Storage.GCS do
  @moduledoc """
  Google Cloud Storage backend for presigned URL generation and file management.

  Presigned URLs are generated with `GcsSignedUrl`, while deletion is performed
  through the S3-compatible API exposed by GCS via `ExAws`.
  """
  @behaviour Edgehog.Storage.Behaviour

  @presign_expiration_seconds 3600

  @impl Edgehog.Storage.Behaviour
  def create_presigned_urls(file_path) do
    presigned_urls([:get, :put], file_path)
  end

  @impl Edgehog.Storage.Behaviour
  def read_presigned_url(file_path) do
    presigned_urls([:get], file_path)
  end

  @impl Edgehog.Storage.Behaviour
  def delete(file_path) do
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

  defp presigned_urls(verbs, file_path) do
    client = gcs_client()
    bucket = bucket!()

    results =
      verbs
      |> Enum.map(&gen_presigned_url(client, bucket, file_path, &1))
      |> Enum.split_with(&match?({:error, _}, &1))

    case results do
      {[], result} -> {:ok, Enum.into(result, %{})}
      {errors, _} -> {:error, extract_errors(errors)}
    end
  end

  defp gen_presigned_url(client, bucket, file_path, verb) do
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

  defp gcs_client do
    # If `:s3_presign_host_config` has a `storage.googleapis.com` host, then
    # goth is enabled, and `gcp_credentials` should be provided. In this case we
    # can assume the environment `json` is filled.
    :goth
    |> Application.get_env(:json)
    |> Jason.decode!()
    |> GcsSignedUrl.Client.load()
  end

  defp bucket! do
    Application.fetch_env!(:edgehog, :storage_bucket)
  end
end
