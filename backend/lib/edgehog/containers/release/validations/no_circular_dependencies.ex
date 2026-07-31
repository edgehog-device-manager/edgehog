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

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    containers = Ash.Changeset.get_argument(changeset, :containers) || []

    container_dependencies =
      Ash.Changeset.get_argument(changeset, :container_dependencies) || []

    graph = build_graph(containers, container_dependencies)

    case Graph.topsort(graph) do
      false ->
        {:error, field: :container_dependencies, message: "circular dependencies detected"}

      _ids ->
        :ok
    end
  end

  defp build_graph(containers, container_dependencies) do
    graph =
      Enum.reduce(containers, Graph.new(), fn container, graph ->
        Graph.add_vertex(graph, value(container, :id))
      end)

    Enum.reduce(container_dependencies, graph, fn dep, graph ->
      Graph.add_edge(graph, value(dep, :dependency_id), value(dep, :container_id))
    end)
  end

  defp value(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
