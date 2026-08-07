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

defmodule Edgehog.Containers.DeviceMapping.Deployment.Provisioner.Core do
  @moduledoc """
  Device mapping provisioner core functions.

  This module contains all functions required by the provisioner that handle the
  pure provisioning logic, e.g. sending data to the device.
  """

  alias Edgehog.Astarte.Device.AvailableDeviceMappings.DeviceMappingStatus
  alias Edgehog.Config
  alias Edgehog.Devices

  require Logger

  @doc """
  Sends the appropriate messages to the device.

  Returns a `{:noreply, state, timeout}` tuple for the provisioner, with the
  updated state and the timeout after which the send should be retried.
  """
  def send(state) do
    %{
      device_mapping_deployment: device_mapping_deployment,
      deployment: deployment,
      tenant: tenant
    } = state

    new_state =
      device_mapping_deployment
      |> send_to_device(tenant: tenant, deployment: deployment)
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

  def send_to_device(device_mapping_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, device_mapping_deployment} <-
           Ash.load(device_mapping_deployment, [:device_mapping, :device], tenant: tenant),
         {:ok, device_mapping} <-
           Map.fetch(device_mapping_deployment, :device_mapping),
         {:ok, device} <- Map.fetch(device_mapping_deployment, :device),
         {:ok, device} <-
           Devices.send_create_device_mapping_request(device, device_mapping, deployment,
             tenant: tenant
           ) do
      Logger.info("""
        DeviceMapping #{device_mapping.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end

  defp update_state_on_send(:ok, state) do
    Map.put(state, :state, :sent)
  end

  defp update_state_on_send(error, state) do
    %{device_mapping_deployment: %{id: id}} = state

    Logger.warning(
      "Error while sending the deployment #{id}: #{inspect(error)}. The operation will be retried shortly."
    )

    state
  end

  defp increase_retries(state) do
    Map.update!(state, :retries, &Kernel.+(&1, 1))
  end

  @doc """
  Tries to reconcile the device mapping deployment with the property set by the device.

  The device publishes the available device mappings, this function reads such property
  and either finds a state, and sets the device mapping deployment to that state or does
  not find a valid state, therefore the device does not have such device mapping
  deployed, and the function returns :not_found

  Alternatively, if something went wrong while updating the device mapping, an 
  `{:error, _}` is returned.

  Example:
  ```elixir
  Core.reconcile(device_mapping_deployment, tenant: tenant)
  > {:ok, new_device_mapping_deployment}

  Core.reconcile(device_mapping_deployment, tenant: tenant)
  > :not_found
  ```
  """
  def reconcile(device_mapping_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, device_mapping_deployment} <-
           Ash.load(
             device_mapping_deployment,
             [device_mapping: [], device: [:available_device_mappings]],
             tenant: tenant
           ),
         {:ok, device_mapping} <- Map.fetch(device_mapping_deployment, :device_mapping),
         {:ok, device} <- Map.fetch(device_mapping_deployment, :device),
         {:ok, available_device_mappings} <- Map.fetch(device, :available_device_mappings) do
      available_device_mappings
      |> Enum.find(:not_found, &(&1.id == device_mapping.id))
      |> maybe_update(device_mapping_deployment, tenant)
    end
  end

  defp maybe_update(%DeviceMappingStatus{present: present}, device_mapping_deployment, tenant) do
    action = if present, do: :mark_as_present, else: :mark_as_not_present

    # NOTE: this will trigger a publish on the appropriate topic, the
    # provisioner will react to it.
    device_mapping_deployment
    |> Ash.Changeset.for_update(action)
    |> Ash.update(tenant: tenant)
  end

  defp maybe_update(other, _device_mapping_deployment, _tenant), do: other

  @doc """
  exponential backoff timeout.

  Reads from the state; computing the retry timeout with the following formula

  ```
  timeout = pan + (2^retries) + rand(0,1000)
  timeout = min(timeout, max_timeout)
  ```

  - pan       :: the pan component is there to ensure a minimum timeout is
                 guaranteed. The pan is only applied when the device_mapping deployment
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
