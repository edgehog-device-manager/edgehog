#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.Supervisor do
  use Supervisor

  alias Edgehog.UpdateCampaigns.ExecutorRegistry
  alias Edgehog.UpdateCampaigns.ExecutorSupervisor
  alias Edgehog.UpdateCampaigns.Resumer

  @base_children [
    {Registry, name: ExecutorRegistry, keys: :unique},
    ExecutorSupervisor
  ]

  @mix_env Mix.env()

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    children(@mix_env)
    |> Supervisor.init(strategy: :rest_for_one)
  end

  # Ignore dialyzer "The pattern can never match the type" warning. This is emitted because for a
  # given Mix env, only one of the two function heads will be always taken, and dialyzer complains
  # that the other one can never match since it's executed after Mix.env is fixed.
  @dialyzer {:nowarn_function, children: 1}

  defp children(:test = _mix_env) do
    # We do not spawn the Resumer task in the :test env, otherwise we get spurious warnings
    # about DB connections still being checked out while a test case terminates.
    @base_children
  end

  defp children(_mix_env) do
    @base_children ++ [Resumer]
  end
end
