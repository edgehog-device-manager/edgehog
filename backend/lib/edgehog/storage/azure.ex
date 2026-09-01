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

defmodule Edgehog.Storage.Azure do
  @moduledoc """
  Azure Blob Storage backend for presigned URL generation and file management.
  """
  @behaviour Edgehog.Storage.Behaviour

  alias Azurex.Blob.SharedAccessSignature

  @presign_expiration_seconds 3600

  @impl Edgehog.Storage.Behaviour
  def create_presigned_urls(file_path) do
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

  @impl Edgehog.Storage.Behaviour
  def read_presigned_url(file_path) do
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

  @impl Edgehog.Storage.Behaviour
  def delete(file_path) do
    container = bucket!()

    Azurex.Blob.delete_blob(file_path, container)
  end

  defp bucket! do
    Application.fetch_env!(:edgehog, :storage_bucket)
  end

  # URI-encodes each segment of a file path, preserving "/" separators.
  defp uri_encode_path(path) do
    path
    |> String.split("/")
    |> Enum.map_join("/", &URI.encode/1)
  end
end