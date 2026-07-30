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

defmodule Edgehog.Containers.DeviceRequest.Deployment.Provisioner.Core do
  @moduledoc """
  Device request deployment core functions

  This module contains all functions required by the provisioner that handle the business logic
  e.g., sending data to the device
  """

  alias Edgehog.Astarte.Device.AvailableDeviceRequests.DeviceRequestStatus
  alias Edgehog.Config
  alias Edgehog.Devices

  require Logger

  def send(device_request_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, device_request_deployment} <-
           Ash.load(device_request_deployment, [device: [], device_request: [:capabilities]],
             tenant: tenant
           ),
         {:ok, device_request} <-
           Map.fetch(device_request_deployment, :device_request),
         {:ok, device} <- Map.fetch(device_request_deployment, :device),
         {:ok, device} <-
           Devices.send_create_device_request_request(device, device_request, deployment,
             tenant: tenant
           ) do
      Logger.info("""
        Device_Request #{device_request.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end

  @doc """
  Tries to reconcile the device request deployment with the property set by the device.

  The device publishes the available device requests, this function reads such property
  and either finds a state, and sets the device request deployment to that state or does
  not find a valid state, therefore the device does not have such device request
  deployed, and the function returns :not_found

  Alternatively, if something went wrong while updating the device request, an 
  `{:error, _}` is returned.

  Example:
  ```elixir
  Core.reconcile(device_request_deployment, tenant: tenant)
  > {:ok, new_device_request_deployment}

  Core.reconcile(device_request_deployment, tenant: tenant)
  > :not_found
  ```
  """
  def reconcile(device_request_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, device_request_deployment} <-
           Ash.load(
             device_request_deployment,
             [device_request: [], device: [:available_device_requests]],
             tenant: tenant
           ),
         {:ok, device_request} <- Map.fetch(device_request_deployment, :device_request),
         {:ok, device} <- Map.fetch(device_request_deployment, :device),
         {:ok, available_device_requests} <- Map.fetch(device, :available_device_requests) do
      available_device_requests
      |> Enum.find(:not_found, &(&1.id == device_request.id))
      |> maybe_update(device_request_deployment, tenant)
    end
  end

  defp maybe_update(%DeviceRequestStatus{present: present}, device_request_deployment, tenant) do
    action = if present, do: :mark_as_present, else: :mark_as_not_present

    # NOTE: this will trigger a publish on the appropriate topic, the
    # provisioner will react to it.
    device_request_deployment
    |> Ash.Changeset.for_update(action)
    |> Ash.update(tenant: tenant)
  end

  defp maybe_update(other, _device_request_deployment, _tenant), do: other

  @doc """
  exponential backoff timeout.

  Reads from the state; computing the retry timeout with the following formula

  ```
  timeout = pan + (2^retries) + rand(0,1000)
  timeout = min(timeout, max_timeout)
  ```

  - pan       :: the pan component is there to ensure a minimum timeout is
                 guaranteed. The pan is only applied when the device_request deployment
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
