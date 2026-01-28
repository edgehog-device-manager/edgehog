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
defmodule Edgehog.Campaigns.CampaignTarget.Changes.TriggerCampaignSubscription do
  @moduledoc false
  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, {:ok, result} ->
      campaign = result |> Ash.load!(:campaign) |> Map.get(:campaign)

      campaign
      |> Ash.Changeset.for_update(:trigger_subscription, %{},
        tenant: tenant,
        load: [:campaign_targets, :successful_target_count]
      )
      |> Ash.update!()

      {:ok, result}
    end)
  end
end
