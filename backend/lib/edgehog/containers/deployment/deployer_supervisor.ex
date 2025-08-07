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

defmodule Edgehog.Containers.Deployment.DeployerSupervisor do
  @moduledoc false
  use DynamicSupervisor

  alias Edgehog.Containers.Deployment

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_deployer!(deployment) do
    %Deployment{
      id: deployment_id,
      tenant_id: tenant_id
    } = deployment

    deployer_id = {tenant_id, deployment_id}
    name = {:via, Registry, {DeployerRegistry, deployer_id}}

    base_args = [
      name: name,
      deployment_id: deployment_id,
      tenant_id: tenant_id
    ]

    child_spec =
      deployment
      |> deployer_child_spec(base_args)
      |> Supervisor.child_spec(id: deployer_id)

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid

      {:error, reason} ->
        msg = "Deployer for  #{deployment_id} failed to start: #{inspect(reason)}"

        raise msg
    end
  end

  defp deployer_child_spec(deployment, base_args) do
    args = base_args ++ deployer_test_args(deployment)

    {Deployment.Deployer, args}
  end

  # Similarly to UpdateCampaigns.Executor we pass :wait_for_start_execution as
  # an additional argument in a test environment to postpone deployer start to
  # when we are ready to test it
  if Mix.env() == :test do
    defp deployer_test_args(_deployment) do
      [wait_for_start_execution: true]
    end
  else
    defp deployer_test_args(_deployment), do: []
  end

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
