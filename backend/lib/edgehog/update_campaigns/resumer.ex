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

defmodule Edgehog.UpdateCampaigns.Resumer do
  use Task, restart: :transient

  alias Edgehog.UpdateCampaigns.ExecutorSupervisor
  alias Edgehog.UpdateCampaigns.Resumer.Core

  require Logger

  def start_link(_arg) do
    Task.start_link(__MODULE__, :resume, [])
  end

  def resume do
    Logger.info("Resuming Update Campaigns")

    # For each resumable update campaign, we start its executor. `start_executor!/1` already
    # handles the case where the executor is already running (if, e.g., we crashed and we're
    # restarted again).
    Core.stream_resumable_update_campaigns()
    |> Core.for_each_update_campaign(&ExecutorSupervisor.start_executor!/1)

    Logger.info("Finished resuming Update Campaigns")

    :ok
  end
end
