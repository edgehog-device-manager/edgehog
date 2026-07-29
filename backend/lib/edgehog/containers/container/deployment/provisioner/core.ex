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

defmodule Edgehog.Containers.Container.Deployment.Provisioner.Core do
  @moduledoc """
  Provisioner core module.

  This module provides the functions handling the state of the provisioner,
  returning what the provisioner should answer to external users or itself.
  """

  alias Edgehog.Astarte.Device.AvailableContainers.ContainerStatus
  alias Edgehog.Config
  alias Edgehog.Devices

  require Logger

  def send(container_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, container_deployment} <-
           Ash.load(container_deployment, [:container, :device], tenant: tenant),
         {:ok, container} <- Map.fetch(container_deployment, :container),
         {:ok, device} <- Map.fetch(container_deployment, :device),
         {:ok, device} <-
           Devices.send_create_container_request(device, container, deployment, tenant: tenant) do
      Logger.info("""
        Container #{container.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end

  @doc """
  Tries to reconcile the container deployment with the property set by the device.

  The device publishes the available containers, this function reads such property
  and either founds a state, and sets the container deployment to that state or does
  not found a valid state, therefore the device does not have such container
  deployed, and the function returns :not_found

  Alternatively, if something went wrong while updating the container, an 
  `{:error, _}` is returned.

  Example:
  ```elixir
  Core.reconcile(container_deployment, tenant: tenant)
  > {:ok, new_container_deployment}

  Core.reconcile(container_deployment, tenant: tenant)
  > :not_found
  ```
  """
  def reconcile(container_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, container_deployment} <-
           Ash.load(container_deployment, [container: [], device: [:available_containers]],
             tenant: tenant
           ),
         {:ok, container} <- Map.fetch(container_deployment, :container),
         {:ok, device} <- Map.fetch(container_deployment, :device),
         {:ok, available_containers} <- Map.fetch(device, :available_containers) do
      available_containers
      |> Enum.find(:not_found, &(&1.id == container.id))
      |> maybe_update(container_deployment, tenant)
    end
  end

  defp maybe_update(%ContainerStatus{status: status}, container_deployment, tenant) do
    # NOTE: this will trigger a publish on the appropriate topic, the
    # provisioner will react to it.

    action =
      case status do
        "Received" -> :mark_as_received
        "Created" -> :mark_as_created
        "Running" -> :mark_as_running
        "Stopped" -> :mark_as_stopped
      end

    container_deployment
    |> Ash.Changeset.for_update(action)
    |> Ash.update(tenant: tenant)
  end

  defp maybe_update(other, _container_deployment, _tenant), do: other

  @doc """
  exponential backoff timeout.

  Reads from the state; computing the retry timeout with the following formula

  ```
  timeout = pan + (2^retries) + rand(0,1000)
  timeout = min(timeout, max_timeout)
  ```

  - pan       :: the pan component is there to ensure a minimum timeout is
                 guaranteed. The pan is only applied when the container deployment
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
