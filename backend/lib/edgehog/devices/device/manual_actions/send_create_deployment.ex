#
# This file is part of Edgehog.
#
# Copyright 2024-2026 SECO Mind Srl
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

defmodule Edgehog.Devices.Device.ManualActions.SendCreateDeployment do
  @moduledoc false

  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.CreateDeploymentRequest.RequestData

  @send_create_deployment_request_behaviour Application.compile_env(
                                              :edgehog,
                                              :astarte_create_deployment_request_module,
                                              Edgehog.Astarte.Device.CreateDeploymentRequest
                                            )

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    device = changeset.data

    with {:ok, deployment} <- fetch_deployment(changeset),
         {:ok, device} <- Ash.load(device, :appengine_client),
         {:ok, container_ids} <- sort_containers(deployment),
         :ok <- send_request(device, deployment.id, container_ids) do
      {:ok, device}
    end
  end

  defp fetch_deployment(changeset) do
    with {:ok, deployment} <- Ash.Changeset.fetch_argument(changeset, :deployment) do
      Ash.load(
        deployment,
        release: [:containers, :container_dependencies]
      )
    end
  end

  defp sort_containers(deployment) do
    release = deployment.release

    dependency_graph = build_graph(release.containers, release.container_dependencies)

    case Graph.topsort(dependency_graph) do
      false ->
        {:error, "Invalid deployment: circular dependencies detected"}

      ids ->
        {:ok, ids}
    end
  end

  defp build_graph(containers, dependencies) do
    graph =
      Enum.reduce(containers, Graph.new(), fn container, graph ->
        Graph.add_vertex(graph, container.id)
      end)

    Enum.reduce(dependencies, graph, fn dep, graph ->
      Graph.add_edge(graph, dep.dependency_id, dep.container_id)
    end)
  end

  defp send_request(device, deployment_id, container_ids) do
    data = %RequestData{
      id: deployment_id,
      containers: container_ids
    }

    @send_create_deployment_request_behaviour.send_create_deployment_request(
      device.appengine_client,
      device.device_id,
      data
    )
  end
end
