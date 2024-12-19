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

defmodule Edgehog.Containers.Image.Deployment.Supervisor do
  @moduledoc false
  use Supervisor

  alias Edgehog.Containers.Image.Deployment.ExecutorRegistry
  alias Edgehog.Containers.Image.Deployment.ExecutorSupervisor

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
    @mix_env
    |> children()
    |> Supervisor.init(strategy: :rest_for_one)
  end

  @dialyzer {:nowarn_function, children: 1}

  # This could be easy for testing
  defp children(_env) do
    @base_children
  end
end
