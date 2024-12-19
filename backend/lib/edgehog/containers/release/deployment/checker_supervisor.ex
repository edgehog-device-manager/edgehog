#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.Release.Deployment.CheckerSupervisor do
  @moduledoc false
  use DynamicSupervisor

  alias Edgehog.Containers.Release.Deployment
  alias Edgehog.Containers.Release.Deployment.CheckerRegistry

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_checker!(data) do
    %{
      deployment: deployment,
      containers: containers,
      images: images,
      networks: networks
    } = data

    tenant = deployment.tenant_id
    checker_id = {tenant, deployment.id}
    name = {:via, Registry, {CheckerRegistry, checker_id}}

    base_args = [
      name: name,
      deployment: deployment,
      containers: containers,
      networks: networks,
      images: images,
      tenant: tenant
    ]

    child_spec =
      deployment
      |> checker_child_spec(base_args)
      |> Supervisor.child_spec(id: deployment.id)

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid

      {:error, reason} ->
        msg =
          "Release Deployment checker for deployment #{deployment.id} failed to start: " <>
            "#{inspect(reason)}"

        raise msg
    end
  end

  defp checker_child_spec(deployment, base_args) do
    # During tests we add `:wait_for_start_execution` to avoid having the checker running
    # without us being ready to test it
    args = base_args ++ checker_test_args(deployment)

    {Deployment.Checker, args}
  end

  if Mix.env() == :test do
    # Pass additional checker-specific test args only in the test env
    defp checker_test_args(%Deployment{} = _deployment) do
      [wait_for_start_execution: true]
    end
  else
    defp checker_test_args(_deployment), do: []
  end

  # Callbacks

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
