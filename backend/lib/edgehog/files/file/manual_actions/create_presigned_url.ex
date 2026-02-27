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

defmodule Edgehog.Files.File.ManualActions.CreatePresignedUrl do
  @moduledoc """
  The Storage context.
  """
  use Ash.Resource.Actions.Implementation

  alias Edgehog.Config

  @presign_expiration_seconds 3600

  @impl Ash.Resource.Actions.Implementation
  def run(input, _opts, context) do
    create_resource(
      context.tenant.tenant_id,
      input.arguments.repository_id,
      input.arguments.filename
    )
  end

  @doc """
  Generate presigned URLs to upload and download a file via HTTP requests.
  """
  def create_resource(tenant_id, repository_id, filename) do
    bucket = Config.s3_bucket!()
    asset_host = System.get_env("S3_ASSET_HOST", "http://localhost:9000")
    uri = URI.parse(asset_host)

    public_s3_config =
      :s3
      |> ExAws.Config.new()
      |> Map.put(:scheme, uri.scheme <> "://")
      |> Map.put(:host, uri.host)
      |> Map.put(:port, uri.port || 80)

    file_path = "uploads/tenants/#{tenant_id}/repositories/#{repository_id}/files/#{filename}"

    with {:ok, presigned_url_get} <-
           ExAws.S3.presigned_url(public_s3_config, :get, bucket, file_path, expires_in: @presign_expiration_seconds),
         {:ok, presigned_url_put} <-
           ExAws.S3.presigned_url(public_s3_config, :put, bucket, file_path, expires_in: @presign_expiration_seconds) do
      map = %{
        get_url: presigned_url_get,
        put_url: presigned_url_put
      }

      {:ok, map}
    end
  end
end
