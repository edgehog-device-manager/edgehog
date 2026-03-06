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

defmodule Edgehog.Files.File.Changes.DeleteFile do
  @moduledoc """
  Deletes a file from the storage backend that was uploaded via a presigned URL.
  """
  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      delete_old_file(result)
    end)
  end

  defp delete_old_file({:ok, file} = result) do
    tenant_id = file.tenant_id
    repository_id = file.repository_id
    filename = file.name

    file_path = "uploads/tenants/#{tenant_id}/repositories/#{repository_id}/files/#{filename}"

    _ = Edgehog.Storage.delete(file_path)

    result
  end

  defp delete_old_file(result), do: result
end
