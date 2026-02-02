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

defmodule Edgehog.Devices.Reconciler do
  @moduledoc false
  use GenServer, restart: :transient

  alias Edgehog.Devices.Reconciler
  alias Edgehog.Tenants.Tenant

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts \\ []) do
    enabled = Keyword.get(opts, :enabled, true)
    state = %{enabled: enabled}

    if enabled,
      do: Phoenix.PubSub.subscribe(Edgehog.PubSub, "tenants:created")

    {:ok, state, {:continue, :start_reconciliation}}
  end

  @impl GenServer
  def handle_continue(:start_reconciliation, %{enabled: true} = state) do
    _ =
      Tenant
      |> Ash.read!()
      |> Enum.each(&spawn_reconciliation_task/1)

    {:noreply, state}
  end

  @impl GenServer
  def handle_continue(:start_reconciliation, %{enabled: false} = state) do
    Logger.info("Not starting device reconciliation in test environment.")

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%Phoenix.Socket.Broadcast{} = notification, state) do
    tenant = notification.payload.data
    spawn_reconciliation_task(tenant)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) when is_reference(ref) do
    {:noreply, state}
  end

  defp spawn_reconciliation_task(tenant) do
    Task.Supervisor.async(Reconciler.Supervisor, fn ->
      Logger.info("Reconciling tenant #{tenant.slug}")
      Reconciler.Core.reconcile(tenant)
    end)
  end
end
