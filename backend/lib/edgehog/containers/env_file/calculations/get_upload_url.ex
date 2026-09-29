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

defmodule Edgehog.Containers.EnvFile.Calculations.GetUploadUrl do
  @moduledoc """
  Returns a presigned PUT URL the client can use to upload the file
  for a target-less env file.

  The object key is `uploads/tenants/<tenant_id>/env_files/<env_file_id>/file`.
  The object is kept in the bucket after the download request completes so
  redeploys can reuse it. It is deleted when the env file is destroyed.
  """
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation
  alias Edgehog.Containers.EnvFile.Storage, as: EnvFileStorage

  @impl Calculation
  def load(_query, _opts, _context) do
    [:id, :file_name]
  end

  @impl Calculation
  def calculate(records, _opts, context) do
    tenant_id = extract_tenant_id(context)

    Enum.map(records, fn env_file ->
      file_path = EnvFileStorage.file_path(tenant_id, env_file.id, env_file.file_name)

      case EnvFileStorage.create_presigned_urls(file_path) do
        {:ok, %{put_url: put_url}} -> put_url
        {:error, _reason} -> nil
      end
    end)
  end

  defp extract_tenant_id(%{tenant: %{tenant_id: tenant_id}}), do: tenant_id
  defp extract_tenant_id(%{tenant: tenant_id}), do: tenant_id
  defp extract_tenant_id(_), do: nil
end
