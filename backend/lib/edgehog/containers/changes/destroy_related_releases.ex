# This file is part of Edgehog.
#
# Copyright 2025, 2026 SECO Mind Srl
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
defmodule Edgehog.Containers.Changes.DestroyRelatedReleases do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers.Release

  require Ash.Query

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    releases = list_application_releases(changeset.data.id, tenant)

    case undeletable_releases(releases) do
      [] ->
        Ash.Changeset.before_action(changeset, fn cs ->
          destroy_related_releases(releases, tenant)
          cs
        end)

      undeletable ->
        versions =
          undeletable
          |> Enum.map(& &1.version)
          |> Enum.uniq()
          |> Enum.join(", ")

        Ash.Changeset.add_error(
          changeset,
          message:
            "Cannot delete application: the following releases cannot be destroyed: #{versions}"
        )
    end
  end

  defp list_application_releases(application_id, tenant) do
    Release
    |> Ash.Query.filter(application_id == ^application_id)
    |> Ash.read!(tenant: tenant)
  end

  defp undeletable_releases(releases) do
    Enum.reject(releases, fn release ->
      %{valid?: valid} = Ash.Changeset.for_destroy(release, :destroy)
      valid
    end)
  end

  defp destroy_related_releases(releases, tenant) do
    Enum.each(releases, fn release ->
      Ash.destroy!(release, tenant: tenant)
    end)
  end
end
