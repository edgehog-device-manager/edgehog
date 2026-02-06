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

defmodule Edgehog.Campaigns.Campaign.Changes.PauseResumeTest do
  use Edgehog.DataCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.TenantsFixtures

  alias Ash.Error.Invalid
  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.CampaignMechanism.Core, as: MechanismCore

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "pause_campaign/1" do
    test "fails to pause an idle campaign", %{tenant: tenant} do
      campaign = campaign_with_targets_fixture(5, tenant: tenant)

      assert {:error, %Invalid{}} = Campaigns.pause_campaign(campaign)
    end

    test "transitions an in-progress campaign to pausing", %{tenant: tenant} do
      campaign = campaign_with_targets_fixture(5, tenant: tenant)

      campaign =
        MechanismCore.mark_campaign_in_progress!(Any, campaign, DateTime.utc_now())

      assert {:ok, pausing_campaign} = Campaigns.pause_campaign(campaign)
      assert pausing_campaign.status == :pausing
    end

    test "fails to pause a paused campaign", %{tenant: tenant} do
      campaign = campaign_with_targets_fixture(5, tenant: tenant)

      campaign = MechanismCore.mark_campaign_in_progress!(Any, campaign, DateTime.utc_now())
      paused_campaign = MechanismCore.mark_campaign_as_paused!(Any, campaign)

      assert {:error, %Invalid{}} = Campaigns.pause_campaign(paused_campaign)
    end

    test "fails to pause a pausing campaign", %{tenant: tenant} do
      campaign = campaign_with_targets_fixture(5, tenant: tenant)

      campaign = MechanismCore.mark_campaign_in_progress!(Any, campaign, DateTime.utc_now())
      {:ok, pausing_campaign} = Campaigns.pause_campaign(campaign)

      assert {:error, %Invalid{}} = Campaigns.pause_campaign(pausing_campaign)
    end

    test "fails to pause a finished campaign", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(tenant: tenant)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [])

      mechanism = campaign.campaign_mechanism.value
      [target] = campaign.campaign_targets
      _ = MechanismCore.mark_target_as_successful!(mechanism, target)
      finished_campaign = MechanismCore.mark_campaign_as_successful!(mechanism, campaign)

      assert {:error, %Invalid{}} = Campaigns.pause_campaign(finished_campaign)
    end
  end

  describe "resume_campaign/1" do
    test "fails to resume an idle campaign", %{tenant: tenant} do
      campaign = campaign_with_targets_fixture(5, tenant: tenant)

      assert {:error, %Invalid{}} = Campaigns.resume_campaign(campaign)
    end

    test "fails to resume an in-progress campaign", %{tenant: tenant} do
      campaign = campaign_with_targets_fixture(5, tenant: tenant)

      campaign = MechanismCore.mark_campaign_in_progress!(Any, campaign, DateTime.utc_now())

      assert {:error, %Invalid{}} = Campaigns.resume_campaign(campaign)
    end

    test "transitions a paused campaign back to in-progress", %{tenant: tenant} do
      campaign = campaign_with_targets_fixture(5, tenant: tenant)

      campaign = MechanismCore.mark_campaign_in_progress!(Any, campaign, DateTime.utc_now())
      paused_campaign = MechanismCore.mark_campaign_as_paused!(Any, campaign)

      assert {:ok, resumed_campaign} = Campaigns.resume_campaign(paused_campaign)
      assert resumed_campaign.status == :in_progress
    end

    test "fails to resume a pausing campaign", %{tenant: tenant} do
      campaign = campaign_with_targets_fixture(5, tenant: tenant)

      campaign = MechanismCore.mark_campaign_in_progress!(Any, campaign, DateTime.utc_now())
      {:ok, pausing_campaign} = Campaigns.pause_campaign(campaign)

      assert {:error, %Invalid{}} = Campaigns.resume_campaign(pausing_campaign)
    end

    test "fails to resume a finished campaign", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(tenant: tenant)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [])

      mechanism = campaign.campaign_mechanism.value
      [target] = campaign.campaign_targets
      _ = MechanismCore.mark_target_as_successful!(mechanism, target)
      finished_campaign = MechanismCore.mark_campaign_as_successful!(mechanism, campaign)

      assert {:error, %Invalid{}} = Campaigns.resume_campaign(finished_campaign)
    end
  end
end
