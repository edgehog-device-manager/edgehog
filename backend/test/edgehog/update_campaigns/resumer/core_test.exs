#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.Resumer.CoreTest do
  use Edgehog.DataCase, async: true

  import Edgehog.TenantsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout
  alias Edgehog.UpdateCampaigns.UpdateCampaign

  describe "stream_resumable_update_campaigns/0" do
    setup do
      {:ok, tenant: tenant_fixture()}
    end

    test "returns an empty stream if no UpdateCampaigns are present" do
      assert [] = Enum.to_list(stream_resumable_update_campaigns())
    end

    test "returns an empty stream if terminated UpdateCampaigns are present", %{tenant: tenant} do
      _update_campaign = update_campaign_fixture(tenant: tenant)

      assert [] = Enum.to_list(stream_resumable_update_campaigns())
    end

    test "returns update campaign in stream if :idle UpdateCampaigns are present", %{
      tenant: tenant
    } do
      %UpdateCampaign{id: update_campaign_id, tenant_id: tenant_id} =
        update_campaign_with_targets_fixture(20, tenant: tenant)

      assert [update_campaign] = Enum.to_list(stream_resumable_update_campaigns())

      assert update_campaign.tenant_id == tenant.tenant_id
      assert update_campaign.tenant_id == tenant_id
      assert update_campaign.id == update_campaign_id
      assert update_campaign.status == :idle
    end

    test "returns update campaign in stream if :in_progress UpdateCampaigns are present", %{
      tenant: tenant
    } do
      %UpdateCampaign{id: update_campaign_id, tenant_id: tenant_id} =
        20
        |> update_campaign_with_targets_fixture(tenant: tenant)
        |> PushRollout.Core.mark_update_campaign_as_in_progress!()

      assert [update_campaign] = Enum.to_list(stream_resumable_update_campaigns())

      assert update_campaign.tenant_id == tenant.tenant_id
      assert update_campaign.tenant_id == tenant_id
      assert update_campaign.id == update_campaign_id
      assert update_campaign.status == :in_progress
    end

    test "returns update campaigns for all tenants", %{tenant: tenant} do
      %UpdateCampaign{id: update_campaign_id, tenant_id: tenant_id} =
        update_campaign_with_targets_fixture(20, tenant: tenant)

      other_tenant = tenant_fixture()

      %UpdateCampaign{id: other_update_campaign_id, tenant_id: other_tenant_id} =
        update_campaign_with_targets_fixture(20, tenant: other_tenant)

      assert update_campaigns = Enum.to_list(stream_resumable_update_campaigns())
      assert length(update_campaigns) == 2

      minimized_campaigns =
        Enum.map(update_campaigns, fn update_campaign ->
          %{id: update_campaign.id, tenant_id: update_campaign.tenant_id}
        end)

      assert %{id: update_campaign_id, tenant_id: tenant_id} in minimized_campaigns
      assert %{id: other_update_campaign_id, tenant_id: other_tenant_id} in minimized_campaigns
    end
  end

  defp stream_resumable_update_campaigns do
    UpdateCampaign
    |> Ash.Query.for_read(:read_all_resumable)
    |> Ash.stream!()
  end
end
