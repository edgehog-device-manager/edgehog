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

defmodule Edgehog.Containers.Release.Validations.NoCircularDependencies do
  @moduledoc false

  use Ash.Resource.Validation

  alias Edgehog.Containers.Release.Dependencies

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, %{tenant: tenant}) do
    containers = Ash.Changeset.get_argument(changeset, :containers) || []
    container_dependencies = Ash.Changeset.get_argument(changeset, :container_dependencies) || []

    with {:ok, resolved} <- Dependencies.resolve_containers(containers, tenant) do
      pairs = Dependencies.dependency_pairs(containers, container_dependencies, resolved)
      graph = build_graph(resolved, pairs)

      case Graph.topsort(graph) do
        false ->
          {:error, field: :container_dependencies, message: "circular dependencies detected"}

        _sorted ->
          :ok
      end
    end
  end

  defp build_graph(resolved_containers, dependency_pairs) do
    graph =
      Enum.reduce(resolved_containers, Graph.new(), fn container, graph ->
        Graph.add_vertex(graph, container.name)
      end)

    Enum.reduce(dependency_pairs, graph, fn {container_name, dependency_name}, graph ->
      Graph.add_edge(graph, dependency_name, container_name)
    end)
  end
end
