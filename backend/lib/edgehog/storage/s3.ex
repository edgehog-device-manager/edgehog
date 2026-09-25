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

defmodule Edgehog.Storage.S3 do
  @moduledoc """
  AWS S3 backend for presigned URL generation and file management.

  Uses the external (public) host configured in `:s3_presign_host_config` so
  that generated presigned URLs are reachable by clients outside the cluster.
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
    config = s3_config()
    bucket = bucket!()

    results =
      verbs
      |> Enum.map(&gen_presigned_url(config, bucket, file_path, &1))
      |> Enum.split_with(&match?({:error, _}, &1))

    case results do
      {[], result} -> {:ok, Enum.into(result, %{})}
      {errors, _} -> {:error, extract_errors(errors)}
    end
  end

  defp gen_presigned_url(config, bucket, file_path, verb) do
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

  defp extract_errors(errors) do
    Enum.map(errors, fn {:error, error} -> error end)
  end

  # Builds an ExAws S3 config that points to the *external* (public) S3 host so
  # that presigned URLs are reachable by clients outside the cluster.
  defp s3_config do
    overrides = Application.get_env(:edgehog, :s3_presign_host_config, %{})

    :s3
    |> ExAws.Config.new()
    |> Map.merge(overrides)
  end

  defp bucket! do
    Application.fetch_env!(:edgehog, :storage_bucket)
  end
end
