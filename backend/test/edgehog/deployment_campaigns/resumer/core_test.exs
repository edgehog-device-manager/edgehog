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

defmodule Edgehog.DeploymentCampaigns.Resumer.CoreTest do
  use Edgehog.DataCase, async: true

  import Edgehog.DeploymentCampaignsFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.DeploymentCampaigns.DeploymentCampaign
  alias Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy

  describe "stream_resumable_deployment_campaigns/0" do
    setup do
      {:ok, tenant: tenant_fixture()}
    end

    test "returns an empty stream if no DeploymentCampaigns are present" do
      assert [] = Enum.to_list(stream_resumable_deployment_campaigns())
    end

    test "returns an empty stream if terminated DeploymentCampaigns are present", %{
      tenant: tenant
    } do
      _deployment_campaign = deployment_campaign_fixture(tenant: tenant)

      assert [] = Enum.to_list(stream_resumable_deployment_campaigns())
    end

    test "returns deployment campaign in stream if :idle DeploymentCampaigns are present", %{
      tenant: tenant
    } do
      %DeploymentCampaign{id: deployment_campaign_id, tenant_id: tenant_id} =
        deployment_campaign_with_targets_fixture(20, tenant: tenant)

      assert [deployment_campaign] = Enum.to_list(stream_resumable_deployment_campaigns())

      assert deployment_campaign.tenant_id == tenant.tenant_id
      assert deployment_campaign.tenant_id == tenant_id
      assert deployment_campaign.id == deployment_campaign_id
      assert deployment_campaign.status == :idle
    end

    test "returns deployment campaign in stream if :in_progress DeploymentCampaigns are present",
         %{
           tenant: tenant
         } do
      %DeploymentCampaign{id: deployment_campaign_id, tenant_id: tenant_id} =
        20
        |> deployment_campaign_with_targets_fixture(tenant: tenant)
        |> Lazy.Core.mark_deployment_campaign_in_progress!()

      assert [deployment_campaign] = Enum.to_list(stream_resumable_deployment_campaigns())

      assert deployment_campaign.tenant_id == tenant.tenant_id
      assert deployment_campaign.tenant_id == tenant_id
      assert deployment_campaign.id == deployment_campaign_id
      assert deployment_campaign.status == :in_progress
    end

    test "returns deployment campaigns for all tenants", %{tenant: tenant} do
      %DeploymentCampaign{id: deployment_campaign_id, tenant_id: tenant_id} =
        deployment_campaign_with_targets_fixture(20, tenant: tenant)

      other_tenant = tenant_fixture()

      %DeploymentCampaign{id: other_deployment_campaign_id, tenant_id: other_tenant_id} =
        deployment_campaign_with_targets_fixture(20, tenant: other_tenant)

      assert deployment_campaigns = Enum.to_list(stream_resumable_deployment_campaigns())
      assert length(deployment_campaigns) == 2

      minimized_campaigns =
        Enum.map(deployment_campaigns, fn deployment_campaign ->
          %{id: deployment_campaign.id, tenant_id: deployment_campaign.tenant_id}
        end)

      assert %{id: deployment_campaign_id, tenant_id: tenant_id} in minimized_campaigns

      assert %{id: other_deployment_campaign_id, tenant_id: other_tenant_id} in minimized_campaigns
    end
  end

  defp stream_resumable_deployment_campaigns do
    DeploymentCampaign
    |> Ash.Query.for_read(:read_all_resumable)
    |> Ash.stream!()
  end
end
