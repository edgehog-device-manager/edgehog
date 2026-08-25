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

defmodule Edgehog.Containers.Deployment.Orchestrator.Core do
  @moduledoc """
  Deployment orchestrator pure functions.
  """

  alias Edgehog.Containers.Container.Deployment.Orchestrator
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Deployment.Provisioner.Core

  require Logger

  def load_resources(state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    case Ash.load(deployment, :container_deployments, tenant: tenant) do
      {:ok, deployment} ->
        container_deployments = Map.fetch!(deployment, :container_deployments)

        {:ok,
         state
         |> Map.put(:deployment, deployment)
         |> Map.put(:container_deployments, container_deployments)}

      {:error, reason} ->
        {:error, reason}
    end
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

  def provision(state) do
    state
    |> provision_containers()
    |> provision_deployment()
  end

  defp provision_containers(state) do
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

    topic = Orchestrator.topic(container_deployment)

    # Subscribe to the container_deployment readiness
    Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

    # Start the container supervisor and its orchestrator
    case Orchestrator.conduct(container_deployment, deployment, tenant) do
      {:ok, _server} ->
        # Append to the queue of containers to wait for readiness
        Map.update(state, :containers_waitlist, [], &[container_deployment | &1])

      {:error, reason} ->
        log_provision_container_start_failed(container_deployment.id, reason)

        state
    end
  end

  defp provision_deployment(state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    topic = Core.topic(deployment)

    # Subscribe to the deployment readiness
    Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

    case Deployment.Provisioner.provision(deployment, tenant) do
      {:ok, _pid} ->
        Map.put(state, :deployment_provisioning, :started)

      {:error, reason} ->
        log_provision_deployment_start_failed(deployment.id, reason)

        Map.put(state, :deployment_provisioning, :started)
    end
  end

  # Logging functions

  def log_orchestrator_started(deployment_id, mode) do
    Logger.debug(
      "Starting an orchestrator for deployment #{deployment_id}, in #{inspect(mode)} mode"
    )
  end

  def log_resources_loaded(deployment_id) do
    Logger.debug("Loaded resources for deployment #{deployment_id}")
  end

  def log_load_resources_failed(deployment_id, reason) do
    Logger.error("""
    Error while loading the resources for deployment #{deployment_id}: #{inspect(reason)}.

    The deployment will be marked as failed.
    """)
  end

  def log_provisioning_started(deployment_id) do
    Logger.debug("Provisioned resources for deployment #{deployment_id}")
  end

  def log_readiness_check(deployment_id, ready) do
    Logger.debug("Deployment #{deployment_id} ready?: #{ready}")
  end

  def log_deployment_ready(deployment_id) do
    Logger.debug(
      "Orchestrator for deployment #{deployment_id} received a readiness event for the deployment."
    )
  end

  def log_container_ready(deployment_id, container_deployment_id) do
    Logger.debug(
      "Orchestrator for deployment #{deployment_id} received a readiness event for the container deployment #{container_deployment_id}"
    )
  end

  def log_deployment_failure(deployment_id) do
    Logger.warning(
      "Orchestrator for deployment #{deployment_id} received a failure event for the deployment. Failing the deployment."
    )
  end

  def log_container_failure(deployment_id, container_deployment_id) do
    Logger.warning(
      "Orchestrator for deployment #{deployment_id} received a failure event for the container deployment #{container_deployment_id}. Failing the deployment."
    )
  end

  def log_orchestrator_completed(deployment_id) do
    Logger.debug(
      "Terminating deployment orchestrator for deployment #{deployment_id}. The deployment is ready."
    )
  end

  def log_broadcasting_readiness(deployment_id, topic) do
    Logger.debug("Broadcasting readiness for deployment #{deployment_id}", topic: topic)
  end

  def log_running_ready_actions(deployment_id) do
    Logger.debug("Running ready actions for deployment #{deployment_id}")
  end

  def log_ready_actions_failed(deployment_id, reason) do
    Logger.warning(
      "Could not run ready actions for deployment #{deployment_id}: #{inspect(reason)}"
    )
  end

  def log_deployment_provisioned(deployment_id) do
    Logger.info("Deployment #{deployment_id} successfully provisioned.")
  end

  def log_provisioning_failed(deployment_id) do
    Logger.warning("Deployment #{deployment_id} provisioning failed. Marking it as timed out.")
  end

  def log_provision_container_start_failed(container_deployment_id, reason) do
    Logger.warning(
      "Error while starting the supervisor for container deployment #{container_deployment_id}: #{inspect(reason)}"
    )
  end

  def log_provision_deployment_start_failed(deployment_id, reason) do
    Logger.warning(
      "Error while starting the provisioner for deployment #{deployment_id}: #{inspect(reason)}"
    )
  end
end
