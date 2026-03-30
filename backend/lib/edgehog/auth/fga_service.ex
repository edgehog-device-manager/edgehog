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

defmodule Edgehog.Auth.FGAService do
  @moduledoc """
  The edgehog FGA publisher.

  This module uses openfga's gRPC api to create all necessary resources based on the application's introspection.
  """

  use GenServer, restart: :transient

  ## API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def check(subj, rel, obj) do
    tuple = {subj, rel, obj}
    GenServer.call(__MODULE__, {:check, tuple})
  end

  ## CALLBACKS

  @impl GenServer
  def init(args) do
    # Crash if no provider was specified
    {provider, args} = Keyword.pop!(args, :provider)

    case provider.init_context(args) do
      {:ok, context} -> {:ok, {provider, context}, {:continue, :create_resources}}
      {:error, error} -> {:stop, error}
    end
  end

  @impl GenServer
  def handle_continue(:create_resources, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:check, tuple}, _from, {provider, context} = state) do
    check = provider.check(tuple, context)

    case check do
      {:error, error} -> {:reply, error, state}
      {response, new_context} -> {:reply, response, {provider, new_context}}
    end
  end
end
