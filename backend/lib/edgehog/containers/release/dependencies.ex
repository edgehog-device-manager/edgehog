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

defmodule Edgehog.Containers.Release.Dependencies do
  @moduledoc """
  Helpers shared by the release validations and changes to resolve the
  container dependencies of a release.

  Dependencies can be expressed in two ways:

  - explicitly, through the `container_dependencies` argument, which
    references existing containers by id;
  - implicitly, through the `depends_on` names of the containers.

  Both are normalized into `{container_name, dependency_name}` pairs, where
  every container is identified by name.
  """

  alias Edgehog.Containers.Container

  require Ash.Query

  @doc """
  Resolves the containers of a release from the `containers` argument.

  Containers referenced by id are fetched from the database, while inline
  containers are only represented by their name.
  """
  def resolve_containers(containers, tenant) do
    {referenced, inline} = Enum.split_with(containers, &Map.get(&1, :id))

    with {:ok, fetched} <- fetch_by_id(referenced, tenant) do
      inline_containers =
        inline
        |> Enum.map(&%{id: nil, name: Map.get(&1, :name)})
        |> Enum.reject(&is_nil(&1.name))

      {:ok, inline_containers ++ fetched}
    end
  end

  @doc """
  Returns the `{container_name, dependency_name}` pairs of a release.

  Explicit `container_dependencies` entries are resolved against the already
  resolved containers: entries referencing unknown containers are ignored,
  since they are rejected by foreign keys when created. The `depends_on`
  names of the containers are turned into pairs as well.
  """
  def dependency_pairs(containers, container_dependencies, resolved_containers) do
    id_to_name = Map.new(resolved_containers, &{&1.id, &1.name})

    explicit_pairs =
      Enum.flat_map(container_dependencies, fn dependency ->
        container_name = Map.get(id_to_name, Map.get(dependency, :container_id))
        dependency_name = Map.get(id_to_name, Map.get(dependency, :dependency_id))

        if container_name && dependency_name do
          [{container_name, dependency_name}]
        else
          []
        end
      end)

    implicit_pairs =
      Enum.flat_map(containers, fn container ->
        container_name = container_name(container, id_to_name)
        depends_on = Map.get(container, :depends_on) || []

        if container_name do
          Enum.map(depends_on, &{container_name, &1})
        else
          []
        end
      end)

    explicit_pairs ++ implicit_pairs
  end

  defp fetch_by_id(references, tenant) do
    ids = Enum.map(references, & &1.id)

    Container
    |> Ash.Query.filter(id in ^ids)
    |> Ash.read(tenant: tenant)
  end

  defp container_name(container, id_to_name) do
    case Map.get(container, :id) do
      nil -> Map.get(container, :name)
      id -> Map.get(id_to_name, id)
    end
  end
end
