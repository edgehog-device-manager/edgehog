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

defmodule Edgehog.Containers.Image.Deployment.Provisioner.Core do
  @moduledoc """
  Image provisioner core functions.

  This module contains all functions required by the provisioner that handle the
  pure provisioning logic, e.g. sending data to the device.
  """

  alias Edgehog.Astarte.Device.AvailableImages.ImageStatus
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
      image_deployment: image_deployment,
      deployment: deployment,
      tenant: tenant
    } = state

    new_state =
      image_deployment
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

  def send_to_device(image_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, image_deployment} <- Ash.load(image_deployment, [:image, :device], tenant: tenant),
         {:ok, image} <- Map.fetch(image_deployment, :image),
         {:ok, device} <- Map.fetch(image_deployment, :device),
         {:ok, device} <-
           Devices.send_create_image_request(device, image, deployment, tenant: tenant) do
      Logger.info("""
        Image #{image.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end

  defp update_state_on_send(:ok, state) do
    Map.put(state, :state, :sent)
  end

  defp update_state_on_send(error, state) do
    %{image_deployment: %{id: id}} = state

    Logger.warning(
      "Error while sending the deployment #{id}: #{inspect(error)}. The operation will be retried shortly."
    )

    state
  end

  defp increase_retries(state) do
    Map.update!(state, :retries, &Kernel.+(&1, 1))
  end

  @doc """
  Tries to reconcile the image deployment with the property set by the device.

  The device publishes the available images, this function reads such property
  and either finds a state, and sets the image deployment to that state or does
  not find a valid state, therefore the device does not have such image
  deployed, and the function returns :not_found

  Alternatively, if something went wrong while updating the image, an 
  `{:error, _}` is returned.

  Example:
  ```elixir
  Core.reconcile(image_deployment, tenant: tenant)
  > {:ok, new_image_deployment}

  Core.reconcile(image_deployment, tenant: tenant)
  > :not_found
  ```
  """
  def reconcile(image_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, image_deployment} <-
           Ash.load(image_deployment, [image: [], device: [:available_images]], tenant: tenant),
         {:ok, image} <- Map.fetch(image_deployment, :image),
         {:ok, device} <- Map.fetch(image_deployment, :device),
         {:ok, available_images} <- Map.fetch(device, :available_images) do
      available_images
      |> Enum.find(:not_found, &(&1.id == image.id))
      |> maybe_update(image_deployment, tenant)
    end
  end

  defp maybe_update(%ImageStatus{pulled: pulled}, image_deployment, tenant) do
    action = if pulled, do: :mark_as_pulled, else: :mark_as_unpulled

    # NOTE: this will trigger a publish on the appropriate topic, the
    # provisioner will react to it.
    image_deployment
    |> Ash.Changeset.for_update(action)
    |> Ash.update(tenant: tenant)
  end

  defp maybe_update(other, _image_deployment, _tenant), do: other

  @doc """
  exponential backoff timeout.

  Reads from the state; computing the retry timeout with the following formula

  ```
  timeout = pan + (2^retries) + rand(0,1000)
  timeout = min(timeout, max_timeout)
  ```

  - pan       :: the pan component is there to ensure a minimum timeout is
                 guaranteed. The pan is only applied when the image deployment
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
