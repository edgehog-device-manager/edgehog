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

defmodule Edgehog.UpdateCampaigns.ExecutorSupervisor do
  use DynamicSupervisor

  alias Edgehog.UpdateCampaigns.ExecutorRegistry
  alias Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout
  alias Edgehog.UpdateCampaigns.UpdateCampaign

  require Logger

  # Public API

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_executor!(update_campaign) do
    %UpdateCampaign{
      id: update_campaign_id,
      rollout_mechanism: %{value: rollout_mechanism},
      tenant_id: tenant_id
    } = update_campaign

    executor_id = {tenant_id, update_campaign_id}
    name = {:via, Registry, {ExecutorRegistry, executor_id}}

    base_args = [
      name: name,
      update_campaign_id: update_campaign_id,
      tenant_id: tenant_id
    ]

    child_spec =
      executor_child_spec(rollout_mechanism, base_args)
      |> Supervisor.child_spec(id: executor_id)

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid

      {:error, reason} ->
        msg =
          "Update Campaign executor for campaign #{update_campaign_id} failed to start: " <>
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

  if Mix.env() == :test do
    # Pass additional executor-specific test args only in the test env
    defp executor_test_args(%PushRollout{} = _rollout_mechanism) do
      [wait_for_start_execution: true]
    end
  else
    defp executor_test_args(_rollout), do: []
  end

  # Callbacks

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
