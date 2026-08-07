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

defmodule Edgehog.Containers.Deployment.Provisioner.Core do
  @moduledoc """
  Deployment provisioner core functions.

  This module contains all functions required by the provisioner that handle the
  pure provisioning logic, e.g. sending data to the device.
  """

  alias Edgehog.Astarte.Device.AvailableDeployments.DeploymentStatus
  alias Edgehog.Config
  alias Edgehog.Devices

  require Logger

  @deployment_ready_states [:started, :stopped]

  @doc """
  Sends the appropriate messages to the device.

  Returns a `{:noreply, state, timeout}` tuple for the provisioner, with the
  updated state and the timeout after which the send should be retried.
  """
  def send(state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = state

    new_state =
      deployment
      |> send_to_device(tenant: tenant)
      |> update_state_on_send(state)

    {:noreply, new_state, timeout(new_state)}
  end

  def maybe_send(state) do
    retries = Map.fetch!(state, :retries)
    max_retries = Config.max_retries!()

    if retries < max_retries do
      state
      |> increase_retries()
      |> send()
    else
      {:stop, {:shutdown, :max_retries}, state}
    end
  end

  def maybe_early_terminate(%{device_online?: device_online?} = state, next_step) do
    if device_online? do
      next_step
    else
      {:stop, {:shutdown, :device_offline}, state}
    end
  end

  def ready?(deployment) do
    deployment.state in @deployment_ready_states
  end

  def send_to_device(deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, deployment} <- Ash.load(deployment, :device, tenant: tenant),
         device = deployment.device,
         {:ok, device} <-
           Devices.send_create_deployment_request(device, deployment, tenant: tenant) do
      deployment
      |> Ash.Changeset.for_update(:mark_as_sent, %{}, tenant: tenant)
      |> Ash.update!()

      Logger.info("""
        Deployment #{deployment.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end

  defp update_state_on_send(:ok, state) do
    Map.put(state, :state, :sent)
  end

  defp update_state_on_send(error, state) do
    %{deployment: %{id: id}} = state

    Logger.warning(
      "Error while sending the deployment #{id}: #{inspect(error)}. The operation will be retried shortly."
    )

    state
  end

  defp increase_retries(state) do
    Map.update!(state, :retries, &Kernel.+(&1, 1))
  end

  @doc """
  Tries to reconcile the deployment with the property set by the device.

  The device publishes the available deployments, this function reads such property
  and either finds a state, and sets the deployment to that state or does
  not find a valid state, therefore the device does not have such deployment
  deployed, and the function returns :not_found

  Alternatively, if something went wrong while updating the deployment, an 
  `{:error, _}` is returned.

  Example:
  ```elixir
  Core.reconcile(deployment, tenant: tenant)
  > {:ok, new_deployment}

  Core.reconcile(deployment, tenant: tenant)
  > :not_found
  ```
  """
  def reconcile(deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, deployment} <-
           Ash.load(deployment, [device: [:available_deployments]], tenant: tenant),
         {:ok, device} <- Map.fetch(deployment, :device),
         {:ok, available_deployments} <- Map.fetch(device, :available_deployments) do
      available_deployments
      |> Enum.find(:not_found, &(&1.id == deployment.id))
      |> maybe_update(deployment, tenant)
    end
  end

  defp maybe_update(%DeploymentStatus{status: status}, deployment, tenant) do
    # NOTE: this will trigger a publish on the appropriate topic, the
    # provisioner will react to it.

    action =
      case status do
        :started -> :mark_as_started
        :stopped -> :mark_as_stopped
      end

    deployment
    |> Ash.Changeset.for_update(action)
    |> Ash.update(tenant: tenant)
  end

  defp maybe_update(other, _deployment, _tenant), do: other

  @doc """
  exponential backoff timeout.

  Reads from the state; computing the retry timeout with the following formula

  ```
  timeout = pan + (2^retries) + rand(0,1000)
  timeout = min(timeout, max_timeout)
  ```

  - pan       :: the pan component is there to ensure a minimum timeout is
                 guaranteed. The pan is only applied when the deployment
                 has been sent, and therefore we're waiting for astarte triggers
  - 2^retries :: this is the exponential component, increases at each retry to
                 ensure we don't DDoS astarte/the device.
  - rand      :: a random (between 0 and 1s) ensures no synchronization errors
                 appear.
  """
  def timeout(state) do
    %{
      state: d_state,
      retries: retries
    } = state

    pan = pan(d_state)

    exp = :math.pow(2, retries)

    rand = Enum.random(0..1000)

    max_timeout = Config.message_max_timeout!()

    pan
    |> Kernel.+(exp)
    |> Kernel.+(rand)
    |> min(max_timeout)
    |> round()
  end

  defp pan(:sent), do: Config.message_min_timeout!()
  defp pan(:init), do: 0
end
