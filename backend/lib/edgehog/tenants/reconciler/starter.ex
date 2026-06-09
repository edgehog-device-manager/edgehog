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

defmodule Edgehog.Tenants.Reconciler.Starter do
  @moduledoc """
  Tenant reconciler starter.

  At application start this server reads all the tenants available in the db and starts their reconcilers.
  """
  use GenServer, restart: :transient

  alias Edgehog.Tenants.Reconciler

  require Logger

  @retry_interval to_timeout(minute: 10)

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    tenants = Ash.read!(Edgehog.Tenants.Tenant)

    state = %{tenants: tenants}

    {:ok, state, {:continue, :start_reconcilers}}
  end

  @impl GenServer
  def handle_continue(:start_reconcilers, %{tenants: tenants} = state) do
    case start_reconcilers(tenants) do
      :ok -> {:stop, :normal, state}
      :error -> {:noreply, state, @retry_interval}
    end
  end

  defp start_reconcilers(tenants) do
    tenants
    |> Enum.map(&Reconciler.start_reconciler/1)
    |> Enum.reject(fn
      {:ok, _} -> true
      :ignore -> true
      {:error, {:already_started, _}} -> true
      _ -> false
    end)
    |> maybe_log_errors()
  end

  defp maybe_log_errors([]),
    do: :ok

  defp maybe_log_errors(errors) do
    message = """
    Errors found when starting reconcilers for tenants already present in the database.
    Maybe a misconfiguration error? We'll try again to start the reconciliation in #{@retry_interval} seconds!

    Errors:
    #{inspect(errors)}
    """

    Logger.error(message)

    :error
  end
end
