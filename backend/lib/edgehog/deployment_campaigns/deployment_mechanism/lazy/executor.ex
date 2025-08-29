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

defmodule Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Executor do
  @moduledoc false
  use GenStateMachine, restart: :transient, callback_mode: [:handle_event_function, :state_enter]

  # Public API

  def start_link(args) do
    name = args[:name] || __MODULE__

    GenStateMachine.start_link(__MODULE__, args, name: name)
  end

  # Callbacks

  @impl GenStateMachine
  def init(_opts) do
    # TODO
    :ignore
  end
end
