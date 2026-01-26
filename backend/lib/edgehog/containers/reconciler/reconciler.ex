#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Reconciler do
  @moduledoc """
  Reconciler for container-related data between the device and the backend.

  When a device connects a timeout gets set up: after a configurable amount of
  time the reconciler goes trough all the data published by the device and
  reconciles the state of the backend with the state of the astarte messages.

  This is useful for a couple of reasons: the backend might have missed some
  messages in trigger handling, the device might have not re-published some
  property, not triggering a trigger and so on.

  This process ensures that the state of the device is eventually consistent
  with astarte state.
  """

  use GenServer, restart: :transient

  alias Edgehog.Containers.Reconciler.Core

  require Ash.Query
  require Logger

  defstruct [
    :device_id
  ]

  # median time per device to setup the reconciliation timer. This is just an
  # heuristic based on online articles about database performance (which affect
  # task setup as the device number is read from the database).
  @comp_time_per_device 200

  # 10 minutes
  @ten_min 10 * 60 * 1000
  # 5 minmutes
  @five_min 5 * 60 * 1000

  # APIs
  def start_link(args) do
    tenant = Keyword.fetch!(args, :tenant)

    GenServer.start_link(__MODULE__, args, name: name(tenant))
  end

  def stop_device(device, tenant) do
    tenant
    |> name()
    |> GenServer.cast({:stop, device})
  end

  def register_device(device, tenant) do
    device_id = device.id

    if Edgehog.Devices.Device
       |> Ash.Query.filter(id == ^device_id)
       |> Ash.exists?(tenant: tenant),
       do: tenant |> name() |> GenServer.cast({:register, device}),
       else: {:error, :device_not_found}
  end

  # Callbacks

  @impl GenServer
  def init(args) do
    tenant = Keyword.fetch!(args, :tenant)
    {online_devices_n, online_devices} = Core.online_devices(tenant)

    state =
      online_devices
      |> Enum.reduce(%{}, &do_register_device/2)
      |> Map.put(:tenant, tenant)
      |> Map.put(:online, online_devices_n)

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:register, device}, state) do
    tenant = Map.get(state, :tenant, nil)

    new_state = do_register_device(device, state)

    # When called, reconcile the device state with astarte
    reconcile(device.id, tenant)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:stop, device}, %{tenant: tenant} = state) do
    Logger.info("Stopping server for device #{device.device_id}")

    new_state =
      case Map.fetch(state, device.id) do
        {:ok, timer_ref} ->
          Process.cancel_timer(timer_ref)
          # Reconcile one last time with astarte before removing timers.
          reconcile(device.id, tenant)
          Map.delete(state, device.id)

        :error ->
          Logger.warning("Device #{device.device_id} was not registered in the reconciler.")
          state
      end

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:reconcile, device_id}, %{tenant: tenant} = state) do
    Logger.info("Reconciling device #{device_id} with astarte container interfaces")

    reconcile(device_id, tenant)
    timer_ref = Process.send_after(self(), {:reconcile, device_id}, reconcile_timeout(tenant))
    new_state = Map.put(state, device_id, timer_ref)

    {:noreply, new_state}
  end

  defp reconcile(device_id, tenant) do
    with {:error, error} <- Core.reconcile(%{device_id: device_id, tenant: tenant}) do
      Logger.warning("Error while reconciling device #{device_id}. #{inspect(error)}")
    end
  end

  defp name(tenant) do
    {:via, Horde.Registry, {Edgehog.Containers.Reconciler.Registry, tenant.tenant_id}}
  end

  defp do_register_device(device, state) do
    Logger.info("Starting timeout for device #{device.device_id}")
    tenant = Map.fetch!(state, :tenant)
    timer_ref = Process.send_after(self(), {:reconcile, device.id}, reconcile_timeout(tenant))
    Map.put(state, device.id, timer_ref)
  end

  # This seems to be spawning _Hawkes processes_ I wont investigate more, this
  # seems to be uniform enough with a variable window of time for
  # reconciliation.
  defp reconcile_timeout(tenant) do
    {online_devices_n, _} = Core.online_devices(tenant)
    mean_time = online_devices_n * @comp_time_per_device

    max = max(@ten_min, mean_time)
    min = max(@five_min, mean_time / 2)

    rand = :rand.uniform()

    # Random number between min and max
    timeout = min + (max - min) * rand

    timeout |> Float.round(0) |> ceil()
  end
end
