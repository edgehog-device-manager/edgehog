#
# This file is part of Edgehog.
#
# Copyright 2023-2025 SECO Mind Srl
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

defmodule Edgehog.Tenants.Reconciler do
  @moduledoc false
  @behaviour Edgehog.Tenants.Reconciler.Behaviour

  use GenServer

  alias Edgehog.Tenants.Reconciler.Core
  alias Edgehog.Tenants.Reconciler.TaskSupervisor
  alias Edgehog.Tenants.Tenant

  @reconcile_interval :timer.minutes(10)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Edgehog.Tenants.Reconciler.Behaviour
  def reconcile_tenant(%Tenant{} = tenant) do
    GenServer.cast(__MODULE__, {:reconcile_tenant, tenant})
  end

  @impl GenServer
  def init(opts) do
    tenant_to_trigger_url_fun = Keyword.fetch!(opts, :tenant_to_trigger_url_fun)

    state = %{tenant_to_trigger_url_fun: tenant_to_trigger_url_fun}

    case Keyword.get(opts, :mode, :periodic) do
      :manual ->
        {:ok, Map.put(state, :mode, :manual)}

      :periodic ->
        schedule_reconciliation(0)

        {:ok, Map.put(state, :mode, :periodic)}
    end
  end

  @impl GenServer
  def handle_info(:reconcile_all, state) do
    %{
      mode: mode,
      tenant_to_trigger_url_fun: tenant_to_trigger_url_fun
    } = state

    if mode == :periodic do
      schedule_reconciliation(@reconcile_interval)
    end

    global_realm_query =
      Edgehog.Astarte.Realm
      |> Ash.Query.for_read(:global)
      |> Ash.Query.load(:realm_management_client)

    Tenant
    |> Ash.read!()
    |> Enum.map(&Ash.load!(&1, [realm: global_realm_query], tenant: &1))
    |> Enum.each(&start_reconciliation_task(&1, tenant_to_trigger_url_fun))

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:reconcile_tenant, tenant}, state) do
    %{
      tenant_to_trigger_url_fun: tenant_to_trigger_url_fun
    } = state

    tenant
    |> Ash.load!([realm: [:realm_management_client]], tenant: tenant)
    |> start_reconciliation_task(tenant_to_trigger_url_fun)

    {:noreply, state}
  end

  defp start_reconciliation_task(%Tenant{} = tenant, tenant_to_trigger_url_fun) do
    Task.Supervisor.start_child(TaskSupervisor, fn ->
      rm_client = tenant.realm.realm_management_client

      Enum.each(Core.list_required_interfaces(), &Core.reconcile_interface!(rm_client, &1))
      trigger_url = tenant_to_trigger_url_fun.(tenant)

      trigger_url
      |> Core.list_required_triggers()
      |> Enum.each(&Core.reconcile_trigger!(rm_client, &1))
    end)
  end

  defp schedule_reconciliation(time) do
    Process.send_after(self(), :reconcile_all, time)

    :ok
  end
end
