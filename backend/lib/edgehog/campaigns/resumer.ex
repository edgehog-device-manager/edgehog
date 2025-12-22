#
# This file is part of Edgehog.
#
# Copyright 2023 - 2026  SECO Mind Srl
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

defmodule Edgehog.Campaigns.Resumer do
  @moduledoc false
  use Task, restart: :transient

  alias Edgehog.Campaigns.ExecutorSupervisor

  require Logger

  def start_link(campaigns_stream) do
    Task.start_link(__MODULE__, :resume, [campaigns_stream])
  end

  def resume(campaigns_stream) do
    Logger.info("Resuming Campaigns")

    # For each resumable campaign, we start its executor. `start_executor!/1` already
    # handles the case where the executor is already running (if, e.g., we crashed and we're
    # restarted again).
    Enum.each(campaigns_stream, &ExecutorSupervisor.start_executor!/1)
    Logger.info("Finished resuming Campaigns")

    :ok
  end
end
