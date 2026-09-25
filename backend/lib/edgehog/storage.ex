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

  Dispatches to the S3, Google Cloud Storage or Azure backend based on the
  configured `:storage_type`.
  """
  @behaviour Edgehog.Storage.Behaviour

  @impl Edgehog.Storage.Behaviour
  def create_presigned_urls(file_path) do
    storage_backend().create_presigned_urls(file_path)
  end

  @impl Edgehog.Storage.Behaviour
  def read_presigned_url(file_path) do
    storage_backend().read_presigned_url(file_path)
  end

  @impl Edgehog.Storage.Behaviour
  def delete(file_path) do
    storage_backend().delete(file_path)
  end

  @doc """
  Returns the configured storage bucket/container name.
  """
  def bucket! do
    Application.fetch_env!(:edgehog, :storage_bucket)
  end

  defp storage_backend do
    case Application.fetch_env!(:edgehog, :storage_type) do
      :s3 -> s3_backend()
      :azure -> Edgehog.Storage.Azure
    end
  end

  defp s3_backend do
    # S3 does not play well with Google storage service, hence if the configured
    # host is Google we need an ad-hoc service to create urls.
    host = :edgehog |> Application.get_env(:s3_presign_host_config, %{}) |> Map.get(:host)

    if host == "storage.googleapis.com" do
      Edgehog.Storage.GCS
    else
      Edgehog.Storage.S3
    end
  end
end
