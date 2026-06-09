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

defmodule Edgehog.Tenants.Reconciler do
  @moduledoc """
  The tenant reconciler.

  This service is responsible for keeping interfaces, triggers and delivery
  policies up to date and running on astarte, handling different astarte
  versions.
  """

  use GenServer, restart: :transient

  alias Edgehog.Config
  alias Edgehog.Tenants.Reconciler.Core

  require Logger

  # =============== API

  @doc deprecated: """
       Tenant reconciliation should happen through the new API.

       see `reconcile/1`
       """
  def reconcile_tenant(tenant), do: reconcile(tenant)

  @doc """
  Reconciles a tenant.

  Sends a new message to the tenant reconciler casting a `:reconcile` message.

  The reconciler server for that tenant proceeds with reconciliation in a separate process.
  """
  def reconcile(tenant) do
    tenant
    |> name()
    |> GenServer.cast(:reconcile)
  end

  def start_reconciler(tenant, opts \\ []) do
    opts
    |> Keyword.put(:tenant, tenant)
    |> start_link()
  end

  def start_link(args) do
    tenant = Keyword.fetch!(args, :tenant)

    GenServer.start_link(__MODULE__, args, name: name(tenant))
  end

  # =============== Init

  @impl GenServer
  def init(opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    timeout = Keyword.get(opts, :timeout, Config.tenant_reconciler_timeout!())

    default_mode = if timeout > 0, do: :auto, else: :manual
    mode = Keyword.get(opts, :mode, default_mode)

    state = %{
      tenant: tenant,
      mode: mode,
      timeout: timeout
    }

    {:ok, state, {:continue, :maybe_start_timeout}}
  end

  # =============== Callbacks

  @impl GenServer
  def handle_continue(:maybe_start_timeout, %{mode: :auto, timeout: timeout} = state) do
    do_reconcile(state)

    # We're in auto mode, reply with a timeout
    {:noreply, state, timeout}
  end

  @impl GenServer
  def handle_continue(:maybe_start_timeout, %{mode: :manual} = state) do
    # In manual mode, just don't
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    do_reconcile(state)
  end

  @impl GenServer
  def handle_cast(:reconcile, state) do
    do_reconcile(state)
  end

  # =============== Helpers

  defp do_reconcile(state) do
    %{
      mode: mode,
      tenant: tenant,
      timeout: timeout
    } = state

    to_return =
      case mode do
        :auto -> {:noreply, state, timeout}
        :manual -> {:noreply, state}
      end

    case Core.reconcile(tenant) do
      :ok -> to_return
      {:error, error} -> log_and_stop(error, state)
    end
  end

  defp log_and_stop(error, state) do
    %{tenant: tenant} = state

    slug = tenant.slug

    Logger.error("""
    An error occurred while reconciling the tenant `#{slug}`: #{inspect(error)}

    To prevent log poison the reconciler will now be stopped. To resume it when the problem is fixed run:

    ```elixir
    Edgehog.Tenants.Reconciler.start_reconciler(tenant, opts)
    ```

    tip: refer to the edgehog doc for valid opts.
    """)

    {:stop, error, state}
  end

  def name(tenant) do
    {:via, Registry, {Edgehog.Tenants.Reconciler.Registry, tenant.tenant_id}}
  end
end
