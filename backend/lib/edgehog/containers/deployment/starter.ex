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

defmodule Edgehog.Containers.Deployment.Starter do
  @moduledoc """
  Deployments starter.

  This server can be started when a device goes online. It will load all the
  pending deployments of such device and start them trough the `Supervisor`.
  """

  use GenServer, restart: :transient

  alias __MODULE__, as: Data
  alias Edgehog.Containers.Deployment.Starter.Core
  alias Edgehog.Devices.Device
  alias Edgehog.Tenants.Tenant

  # the state struct, we can reference it with the %Data{} struct
  defstruct [
    :device,
    :tenant,
    :mode,
    :deployments
  ]

  @test Mix.env() == :test
  @sup Edgehog.Containers.Deployment.Starter.Supervisor

  @doc """
  Registers a new starter under the appropriate supervisor.

  Given a device creates the appropriate child spec and sends it to the
  #{inspect(@sup)} supervisor.

  The process will registry to the appropriate registry according to the
  `name/1` function. See `start_link/1` docs for more.
  """
  def cook(device, tenant, opts \\ []) do
    args =
      opts
      |> Keyword.put(:device, device)
      |> Keyword.put(:tenant, tenant)

    %{slug: slug} = tenant
    %{device_id: device_id} = device
    id = "#{slug}:#{device_id}"

    child_spec = Supervisor.child_spec({__MODULE__, args}, id: id)

    with {:error, {:already_started, pid}} <- DynamicSupervisor.start_child(@sup, child_spec) do
      {:ok, pid}
    end
  end

  @doc """
  Starts a new starter. The service will register to the appropriate registry
  using the `:via` tuple.

  The args must contain a `:device` and a `:tenant` keyword, respectively with
  the device and tenant the operation will be performed for.
  """
  def start_link(args) do
    device = Keyword.fetch!(args, :device)
    tenant = Keyword.fetch!(args, :tenant)

    GenServer.start_link(__MODULE__, args, name: name(device, tenant))
  end

  def name(%Device{device_id: device_id}, %Tenant{slug: slug}) do
    id = "#{slug}:#{device_id}"

    {:via, Registry, {Edgehog.Containers.Deployment.Starter.Registry, id}}
  end

  # Test additional API
  # In test environment, allow to run the process with a message, so that the
  # test process can attach and monitor it
  if @test do
    def run(starter) do
      GenServer.cast(starter, :run)
    end

    @impl GenServer
    def handle_cast(:run, state) do
      {:noreply, state, {:continue, :load}}
    end
  end

  @impl GenServer
  def init(args) do
    device = Keyword.fetch!(args, :device)
    tenant = Keyword.fetch!(args, :tenant)

    mode = Keyword.get(args, :mode, :auto)

    state = %Data{
      device: device,
      tenant: tenant,
      mode: mode
    }

    {:ok, state, {:continue, :maybe_load}}
  end

  @impl GenServer
  def handle_continue(:maybe_load, %{mode: :auto} = state) do
    {:noreply, state, {:continue, :load}}
  end

  @impl GenServer
  def handle_continue(:maybe_load, %{mode: :manual} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_continue(:load, %{device: device, tenant: tenant} = state) do
    case Core.load(device, tenant) do
      {:ok, deployments} ->
        state
        |> Map.put(:deployments, deployments)
        |> then(&{:noreply, &1, {:continue, :start_deployments}})

      {:error, error} ->
        {:stop, state, {:shutdown, error}}
    end
  end

  @impl GenServer
  def handle_continue(:start_deployments, %{deployments: deployments, tenant: tenant} = state) do
    case Core.start(deployments, tenant) do
      [] -> {:stop, :normal, state}
      errors -> {:stop, {:shutdown, {:start_errors, errors}}, state}
    end
  end

  @impl GenServer
  def terminate(:normal, state) do
    %{device: %{device_id: device_id}} = state

    Core.log_start_completed(device_id)
  end

  @impl GenServer
  def terminate({:shutdown, {:start_errors, errors}}, state) do
    %{device: device} = state

    Core.log_start_errors(device)

    Core.log_errors(errors, device)
  end

  @impl GenServer
  def terminate({:shutdown, error}, state) do
    %{device: %{device_id: device_id}} = state
    error = with {:error, error} <- error, do: error

    Core.log_start_unexpected_error(device_id, error)
  end

  @impl GenServer
  def terminate(reason, state) do
    %{device: %{device_id: device_id}} = state

    Core.log_start_terminated(device_id, reason)
  end
end
