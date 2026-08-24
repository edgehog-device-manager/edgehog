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

defmodule Edgehog.Containers.Release.Changes.CreateDependencies do
  @moduledoc """
  Creates the container dependencies of a release after its creation.

  Only dependencies expressed through the `depends_on` names of the containers
  are handled here: they cannot be managed while creating the containers, since
  the depended-on containers may not exist yet. After the release is created,
  every container is persisted and linked to it, so the names can finally be
  resolved to ids.

  Explicit `container_dependencies` reference existing containers by id, so
  they are created by the `manage_relationship` on the create action instead.
  Unresolvable names raise an `ArgumentError`, signaling that the release
  validations did not run.
  """

  use Ash.Resource.Change

  alias Edgehog.Containers.Release.Dependencies
  alias Edgehog.Containers.ReleaseContainerDependencies

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    Ash.Changeset.after_action(changeset, fn changeset, release ->
      with {:ok, release} <- Ash.load(release, [:containers], tenant: tenant) do
        create_dependencies(release, changeset, tenant)
      end
    end)
  end

  defp create_dependencies(release, changeset, tenant) do
    containers = Ash.Changeset.get_argument(changeset, :containers) || []

    name_to_id = Map.new(release.containers, &{&1.name, &1.id})

    inputs =
      containers
      |> Dependencies.dependency_pairs([], release.containers)
      |> Enum.uniq()
      |> Enum.map(fn {container_name, dependency_name} ->
        %{
          release_id: release.id,
          container_id: Map.fetch!(name_to_id, container_name),
          dependency_id: Map.fetch!(name_to_id, dependency_name)
        }
      end)

    case inputs do
      [] ->
        {:ok, release}

      inputs ->
        Ash.bulk_create!(inputs, ReleaseContainerDependencies, :create, tenant: tenant)

        {:ok, release}
    end
  end
end
