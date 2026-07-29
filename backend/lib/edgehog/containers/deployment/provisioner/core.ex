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
  """

  alias Edgehog.Astarte.Device.AvailableDeployments.DeploymentStatus
  alias Edgehog.Config
  alias Edgehog.Devices

  require Logger

  def send(deployment, opts) do
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

    pan =
      case d_state do
        :sent -> Config.message_min_timeout!()
        :init -> 0
      end

    exp = :math.pow(2, retries)

    rand = Enum.random(0..1000)

    max_timeout = Config.message_max_timeout!()

    pan
    |> Kernel.+(exp)
    |> Kernel.+(rand)
    |> min(max_timeout)
    |> round()
  end
end
