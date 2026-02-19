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

defmodule Edgehog.Files.File.BucketStorage do
  @moduledoc """
  Implementation of `Edgehog.Files.File.Storage` that uses a bucket storage (e.g., S3, MinIO) to store files.
  """

  @behaviour Edgehog.Files.File.Storage

  alias Edgehog.Files.File
  alias Edgehog.Files.File.Storage
  alias Edgehog.Files.Uploaders

  @impl Storage
  def store(tenant_id, file_name, repository_id, %Plug.Upload{} = upload) do
    scope = %{
      tenant_id: tenant_id,
      file_name: file_name,
      repository_id: repository_id
    }

    with {:ok, stored_name} <- Uploaders.File.store({upload, scope}) do
      file_url = Uploaders.File.url({stored_name, scope})
      {:ok, file_url}
    end
  end

  @impl Storage
  def delete(%File{} = file) do
    %File{
      url: url,
      tenant_id: tenant_id,
      name: file_name,
      repository_id: repository_id
    } = file

    scope = %{
      tenant_id: tenant_id,
      file_name: file_name,
      repository_id: repository_id
    }

    Uploaders.File.delete({url, scope})
  end
end
