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

defmodule Edgehog.Containers.Deployment.Supervisor.Core do
  @moduledoc """
  Deployment supervisor pure functions.
  """

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Deployment

  def load_resources(state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    deployment = Ash.load!(deployment, [:container_deployments], tenant: tenant)
    container_deployments = Map.fetch!(deployment, :container_deployments)

    Map.put(state, :container_deployments, container_deployments)
  end

  def provision(state) do
    state
    |> provision_containers()
    |> provision_deployment()
  end

  def provision_containers(state) do
    new_state = Map.put(state, :containers_waitlist, [])

    new_state
    |> Map.get(:container_deployments, [])
    |> Enum.reduce(new_state, &provision_container/2)
  end

  defp provision_container(container_deployment, state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = container_deployment

    # Subscribe to the container_deployment readiness
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "provisioning:container_deployments:#{id}")

    # Start the Supervisor
    Container.Deployment.Supervisor.supervise(container_deployment, deployment, tenant)

    # Append to the queue of containers to wait for readiness
    Map.update(state, :containers_waitlist, [], &[container_deployment | &1])
  end

  def provision_deployment(state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = deployment

    # Subscribe to the container_deployment readiness
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "ready:deployments:#{id}")

    # Start the provisioner
    Deployment.Provisioner.provision(deployment, tenant)

    Map.put(state, :deployment_provisioning, :started)
  end

  def ready?(state) do
    deployment_ready = Map.fetch!(state, :deployment_provisioning) == :completed

    containers_ready =
      state
      |> Map.fetch!(:containers_waitlist)
      |> Enum.empty?()

    deployment_ready and containers_ready
  end

  def deployment_ready(state, deployment) do
    %{
      state
      | deployment_provisioning: :completed,
        deployment: deployment
    }
  end

  def container_ready(id, state) do
    id_matches = &(&1.id == id)

    remove_matching_container = &Enum.reject(&1, id_matches)

    Map.update!(state, :containers_waitlist, remove_matching_container)
  end
end
