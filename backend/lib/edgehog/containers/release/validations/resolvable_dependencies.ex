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

defmodule Edgehog.Containers.Release.Validations.ResolvableDependencies do
  @moduledoc false

  use Ash.Resource.Validation

  alias Edgehog.Containers.Release.Dependencies

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, %{tenant: tenant}) do
    containers = Ash.Changeset.get_argument(changeset, :containers) || []
    container_dependencies = Ash.Changeset.get_argument(changeset, :container_dependencies) || []

    with {:ok, resolved} <- Dependencies.resolve_containers(containers, tenant) do
      known_names = MapSet.new(resolved, & &1.name)

      unknown =
        containers
        |> Dependencies.dependency_pairs(container_dependencies, resolved)
        |> Enum.flat_map(fn {container_name, dependency_name} ->
          [container_name, dependency_name]
        end)
        |> Enum.uniq()
        |> Enum.reject(&MapSet.member?(known_names, &1))
        |> Enum.sort()

      case unknown do
        [] ->
          :ok

        unknown ->
          {:error, field: :containers, message: "unknown containers: #{Enum.join(unknown, ", ")}"}
      end
    end
  end
end
