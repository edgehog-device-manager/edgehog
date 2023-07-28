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

defmodule Edgehog.UpdateCampaigns.Resumer.CoreTest do
  use Edgehog.DataCase, async: true
  use Edgehog.AstarteMockCase

  import Edgehog.TenantsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Edgehog.UpdateCampaigns.PushRollout
  alias Edgehog.UpdateCampaigns.Resumer.Core
  alias Edgehog.UpdateCampaigns.UpdateCampaign

  describe "stream_resumable_update_campaigns/0" do
    test "returns an empty stream if no UpdateCampaigns are present" do
      assert [] = Core.stream_resumable_update_campaigns() |> stream_to_list()
    end

    test "returns an empty stream if terminated UpdateCampaigns are present" do
      _update_campaign = update_campaign_fixture()

      assert [] = Core.stream_resumable_update_campaigns() |> stream_to_list()
    end

    test "returns update campaign in stream if :idle UpdateCampaigns are present" do
      %UpdateCampaign{id: update_campaign_id, tenant_id: tenant_id} =
        update_campaign_with_targets_fixture(20)

      assert [update_campaign] = Core.stream_resumable_update_campaigns() |> stream_to_list()

      assert update_campaign.tenant_id == tenant_id
      assert update_campaign.id == update_campaign_id
      assert update_campaign.status == :idle
    end

    test "returns update campaign in stream if :in_progress UpdateCampaigns are present" do
      %UpdateCampaign{id: update_campaign_id, tenant_id: tenant_id} =
        update_campaign_with_targets_fixture(20)
        |> PushRollout.Core.mark_update_campaign_as_in_progress!()

      assert [update_campaign] = Core.stream_resumable_update_campaigns() |> stream_to_list()

      assert update_campaign.tenant_id == tenant_id
      assert update_campaign.id == update_campaign_id
      assert update_campaign.status == :in_progress
    end

    test "returns update campaigns for all tenants" do
      %UpdateCampaign{id: update_campaign_id, tenant_id: tenant_id} =
        update_campaign_with_targets_fixture(20)

      other_tenant = tenant_fixture()
      Repo.put_tenant_id(other_tenant.tenant_id)

      %UpdateCampaign{id: other_update_campaign_id, tenant_id: other_tenant_id} =
        update_campaign_with_targets_fixture(20)

      assert update_campaigns = Core.stream_resumable_update_campaigns() |> stream_to_list()
      assert length(update_campaigns) == 2

      minimized_campaigns =
        Enum.map(update_campaigns, fn update_campaign ->
          %{id: update_campaign.id, tenant_id: update_campaign.tenant_id}
        end)

      assert %{id: update_campaign_id, tenant_id: tenant_id} in minimized_campaigns
      assert %{id: other_update_campaign_id, tenant_id: other_tenant_id} in minimized_campaigns
    end
  end

  describe "for_each_update_campaign/0" do
    test "executes fun for each element of the stream in a transaction" do
      count = Enum.random(1..20)

      # Initialize count resumable update campaigns
      Enum.each(1..count, fn _i -> update_campaign_with_targets_fixture(20) end)

      parent = self()

      fun = fn %UpdateCampaign{} ->
        assert Repo.in_transaction?()
        send(parent, :fun_called)
      end

      assert :ok =
               Core.stream_resumable_update_campaigns()
               |> Core.for_each_update_campaign(fun)

      assert count_fun_called() == count
    end
  end

  defp stream_to_list(stream) do
    # Unroll the stream in a transaction as required by Ecto docs
    {:ok, list} = Repo.transaction(fn -> Enum.to_list(stream) end)

    list
  end

  defp count_fun_called(acc \\ 0) do
    receive do
      :fun_called ->
        count_fun_called(acc + 1)
    after
      1000 ->
        acc
    end
  end
end
