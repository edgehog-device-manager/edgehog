#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
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

defmodule Edgehog.Campaigns.ExecutorSupervisor do
  @moduledoc false
  use DynamicSupervisor

  alias Edgehog.Campaigns.ExecutorRegistry
  alias Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout
  alias Edgehog.UpdateCampaigns.UpdateCampaign

  require Logger

  @mix_env Mix.env()

  # Public API

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Starts an executor for the given campaign in the `ExecutorRegistry` registry,
  with id `{tenant, campaign_id, type}` where `type` is the type of campaign (for
  now only `:ot_update` campaign types are supported).


  """
  def start_executor!(%UpdateCampaign{id: id, rollout_mechanism: %{value: rollout}, tenant_id: tenant_id} = _campaign),
    do: do_start_executor!(id, rollout, tenant_id, :ota_update)

  defp do_start_executor!(campaign_id, rollout_mechanism, tenant_id, type) do
    executor_id = {tenant_id, campaign_id, type}
    name = {:via, Registry, {ExecutorRegistry, executor_id}}

    base_args = [
      name: name,
      campaign_id: campaign_id,
      tenant_id: tenant_id
    ]

    rollout_mechanism
    |> executor_child_spec(base_args)
    |> Supervisor.child_spec(id: executor_id)
    |> start_child!(executor_id)
  end

  defp start_child!(child_spec, {tenant_id, campaign_id, type}) do
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid

      {:error, reason} ->
        msg =
          "(tenant #{tenant_id}) Campaign executor for campaign #{campaign_id} of type #{inspect(type)} failed to start: " <>
            "#{inspect(reason)}"

        raise msg
    end
  end

  defp executor_child_spec(%PushRollout{} = rollout_mechanism, base_args) do
    # During tests we add `:wait_for_start_execution` to avoid having the executor running
    # without us being ready to test it
    args = base_args ++ executor_test_args(rollout_mechanism)

    {PushRollout.Executor, args}
  end

  case @mix_env do
    # Pass additional executor-specific test args only in the test env
    :test ->
      defp executor_test_args(%PushRollout{} = _rollout_mechanism), do: [wait_for_start_execution: true]

    _other ->
      defp executor_test_args(_rollout), do: []
  end

  # Callbacks

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
