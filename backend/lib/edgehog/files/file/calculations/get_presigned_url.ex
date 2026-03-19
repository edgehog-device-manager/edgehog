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

defmodule Edgehog.Files.File.Calculations.GetPresignedUrl do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @files_storage_module Application.compile_env(
                          :edgehog,
                          :files_storage_module,
                          Edgehog.Storage
                        )

  @impl Calculation
  def load(_query, _opts, _context) do
    [:name, :repository_id]
  end

  @impl Calculation
  def calculate(records, _opts, context) do
    Enum.map(records, fn file ->
      tenant_id = context.tenant.tenant_id
      repository_id = file.repository_id
      filename = file.name

      file_path = "uploads/tenants/#{tenant_id}/repositories/#{repository_id}/files/#{filename}"

      case @files_storage_module.read_presigned_url(file_path) do
        {:ok, %{get_url: get_url}} -> get_url
        {:error, _reason} -> nil
      end
    end)
  end
end
