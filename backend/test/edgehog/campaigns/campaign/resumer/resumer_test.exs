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

defmodule Edgehog.Campaigns.Resumer.ResumerTest do
  use Edgehog.DataCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.CampaignMechanism.Core, as: MechanismCore

  setup do
    {:ok, tenant: tenant_fixture()}
  end

  describe "stream_resumable_campaigns/0" do
    test "returns an empty stream if no Campaigns are present" do
      assert [] = Enum.to_list(stream_resumable_campaigns())
    end

    test "returns an empty stream if terminated Campaigns are present", %{
      tenant: tenant
    } do
      _campaign = campaign_fixture(tenant: tenant)

      assert [] = Enum.to_list(stream_resumable_campaigns())
    end

    test "returns deployment campaign in stream if :idle Campaigns are present", %{
      tenant: tenant
    } do
      %Campaign{id: campaign_id, tenant_id: tenant_id} =
        campaign_with_targets_fixture(20, tenant: tenant)

      assert [campaign] = Enum.to_list(stream_resumable_campaigns())

      assert campaign.tenant_id == tenant.tenant_id
      assert campaign.tenant_id == tenant_id
      assert campaign.id == campaign_id
      assert campaign.status == :idle
    end

    test "returns deployment campaign in stream if :in_progress Campaigns are present", %{
      tenant: tenant
    } do
      %Campaign{id: campaign_id, tenant_id: tenant_id} =
        campaign = campaign_with_targets_fixture(20, tenant: tenant)

      _ = MechanismCore.mark_campaign_in_progress!(Any, campaign)

      assert [campaign] = Enum.to_list(stream_resumable_campaigns())

      assert campaign.tenant_id == tenant.tenant_id
      assert campaign.tenant_id == tenant_id
      assert campaign.id == campaign_id
      assert campaign.status == :in_progress
    end

    test "doesn't return deployment campaign in stream if :paused Campaigns are present", %{
      tenant: tenant
    } do
      campaign = campaign_with_targets_fixture(20, tenant: tenant)

      campaign = MechanismCore.mark_campaign_in_progress!(Any, campaign, DateTime.utc_now())
      _paused_campaign = MechanismCore.mark_campaign_as_paused!(Any, campaign)

      assert [] = Enum.to_list(stream_resumable_campaigns())
    end

    test "returns deployment campaign in stream if :pausing Campaigns are present", %{
      tenant: tenant
    } do
      %Campaign{id: campaign_id, tenant_id: tenant_id} =
        campaign = campaign_with_targets_fixture(20, tenant: tenant)

      campaign = MechanismCore.mark_campaign_in_progress!(Any, campaign, DateTime.utc_now())
      _ = Campaigns.pause_campaign(campaign)

      assert [campaign] = Enum.to_list(stream_resumable_campaigns())

      assert campaign.tenant_id == tenant.tenant_id
      assert campaign.tenant_id == tenant_id
      assert campaign.id == campaign_id
      assert campaign.status == :pausing
    end

    test "returns deployment campaigns for all tenants", %{tenant: tenant} do
      %Campaign{id: campaign_id, tenant_id: tenant_id} =
        campaign_with_targets_fixture(20, tenant: tenant)

      other_tenant = tenant_fixture()

      %Campaign{id: other_campaign_id, tenant_id: other_tenant_id} =
        campaign_with_targets_fixture(20,
          tenant: other_tenant
        )

      assert campaigns = Enum.to_list(stream_resumable_campaigns())
      assert length(campaigns) == 2

      minimized_campaigns =
        Enum.map(campaigns, fn campaign ->
          %{id: campaign.id, tenant_id: campaign.tenant_id}
        end)

      assert %{id: campaign_id, tenant_id: tenant_id} in minimized_campaigns

      assert %{id: other_campaign_id, tenant_id: other_tenant_id} in minimized_campaigns
    end
  end

  defp stream_resumable_campaigns do
    Campaign
    |> Ash.Query.for_read(:read_all_resumable)
    |> Ash.stream!()
  end
end
