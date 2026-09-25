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

defmodule Edgehog.Containers.FileBind.Changes.HandleFileBindDeletion do
  @moduledoc """
  Deletes the bucket object uploaded for a target-less file bind.

  Bucket objects are kept after the file download request completes so
  redeploys can reuse them, and are removed only when the file bind itself
  is destroyed. Binds that never received an upload have nothing to delete.
  """
  use Ash.Resource.Change

  alias Edgehog.Containers.FileBind.Storage, as: FileBindStorage

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, &delete_object(&1, &2))
  end

  defp delete_object(changeset, {:ok, file_bind} = result) do
    if file_bind.uploaded do
      tenant_id = changeset.to_tenant
      file_path = FileBindStorage.file_path(tenant_id, file_bind.id, file_bind.file_name)

      # Best effort cleanup
      _ = FileBindStorage.delete(file_path)
    end

    result
  end

  defp delete_object(_changeset, result), do: result
end
