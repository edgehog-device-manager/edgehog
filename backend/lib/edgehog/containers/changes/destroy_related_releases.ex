#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Changes.DestroyRelatedReleases do
  @moduledoc false
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    application =
      Ash.load!(
        changeset.data,
        [:releases],
        reuse_values?: true
      )

    Enum.reduce_while(application.releases, changeset, fn release, changeset_acc ->
      case Ash.destroy(release, tenant: changeset.tenant) do
        :ok ->
          {:cont, changeset_acc}

        {:error, %Ash.Error.Invalid{} = error} ->
          changeset_acc =
            Ash.Changeset.add_error(changeset_acc,
              field: :releases,
              message: Enum.map_join(error.errors, ", ", & &1.message)
            )

          {:halt, changeset_acc}

        {:error, error} ->
          changeset_acc =
            Ash.Changeset.add_error(changeset_acc,
              field: :releases,
              message: "Failed to delete release: #{inspect(error)}"
            )

          {:halt, changeset_acc}
      end
    end)
  end
end
