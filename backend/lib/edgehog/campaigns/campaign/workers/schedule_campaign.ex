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

defmodule Edgehog.Campaigns.Campaign.Workers.ScheduleCampaign do
  @moduledoc """
  This module is used to start Campaigns that have been scheduled at a specific time
  """
  use Oban.Worker,
    queue: :campaigns,
    unique: [
      fields: [:worker, :queue, :args],
      keys: [:id],
      states: [:scheduled],
      period: :infinity
    ],
    replace: [
      scheduled: [:scheduled_at]
    ]

  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.ExecutorSupervisor

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id, "tenant" => tenant} = _args}) do
    with {:ok, campaign} <- Campaigns.fetch_campaign(id, tenant: tenant) do
      _pid = ExecutorSupervisor.start_executor!(campaign)

      {:ok, campaign}
    end
  end
end
