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

defmodule EdgehogWeb.Schema.Subscriptions.Campaign.CampaignSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.CampaignsFixtures

  alias Edgehog.Campaigns

  describe "Campaigns subscription" do
    test "receive data on deployment campaign creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      campaign = campaign_fixture(tenant: tenant, mechanism_type: :deployment_deploy)

      assert_push "subscription:data", push

      assert_created("campaigns", campaign_data, push)

      assert campaign_data["id"] == AshGraphql.Resource.encode_relay_id(campaign)
    end

    test "receive data on update campaign creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      campaign = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)

      assert_push "subscription:data", push

      assert_created("campaigns", campaign_data, push)

      assert campaign_data["id"] == AshGraphql.Resource.encode_relay_id(campaign)
    end

    test "receive data on campaign update", %{socket: socket, tenant: tenant} do
      campaign =
        campaign_with_targets_fixture(2, tenant: tenant, mechanism_type: :deployment_deploy)

      campaigns_updated_query = """
      subscription {
        campaigns {
          updated {
            id
            name
            status
            outcome
          }
        }
      }
      """

      subscribe(socket, query: campaigns_updated_query)

      Campaigns.mark_campaign_successful(campaign)

      assert_push "subscription:data", push

      assert_updated("campaigns", campaign_data, push)

      assert campaign_data["id"] == AshGraphql.Resource.encode_relay_id(campaign)
      assert campaign_data["status"] == "FINISHED"
    end
  end

  describe "Deployment Campaign subscriptions" do
    test "receive data on deployment campaign creation", %{socket: socket, tenant: tenant} do
      deployment_campaigns_created_query = """
      subscription {
        deploymentCampaigns{
          created {
            id
            name
          }
        }
      }
      """

      subscribe(socket, query: deployment_campaigns_created_query)

      campaign = campaign_fixture(tenant: tenant, mechanism_type: :deployment_deploy)

      assert_push "subscription:data", push

      assert_created("deploymentCampaigns", campaign_data, push)

      assert campaign_data["id"] == AshGraphql.Resource.encode_relay_id(campaign)
      assert campaign_data["name"] == campaign.name
    end

    test "does not receive data on update campaign creation", %{socket: socket, tenant: tenant} do
      deployment_campaigns_created_query = """
      subscription {
        deploymentCampaigns{
          created {
            id
            name
          }
        }
      }
      """

      subscribe(socket, query: deployment_campaigns_created_query)

      _campaign = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
      refute_push "subscription:data", _payload, 100
    end
  end

  describe "Update Campaign subscriptions" do
    test "receive data on update campaign creation", %{socket: socket, tenant: tenant} do
      update_campaigns_created_query = """
      subscription {
        updateCampaigns{
          created {
            id
          }
        }
      }
      """

      subscribe(socket, query: update_campaigns_created_query)

      campaign = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)

      assert_push "subscription:data", push

      assert_created("updateCampaigns", campaign_data, push)

      assert campaign_data["id"] == AshGraphql.Resource.encode_relay_id(campaign)
    end

    test "does not receive data on deployment campaign creation", %{
      socket: socket,
      tenant: tenant
    } do
      update_campaigns_created_query = """
      subscription {
        updateCampaigns{
          created {
            id
          }
        }
      }
      """

      subscribe(socket, query: update_campaigns_created_query)

      _campaign = campaign_fixture(tenant: tenant, mechanism_type: :deployment_deploy)
      refute_push "subscription:data", _payload, 100
    end
  end

  describe "Campaign subscription" do
    test "receive data on single campaign update", %{socket: socket, tenant: tenant} do
      campaign =
        campaign_with_targets_fixture(2,
          tenant: tenant,
          mechanism_type: :deployment_deploy
        )

      campaign_updated_query = """
      subscription CampaignUpdated($id: ID!) {
        campaign(id: $id) {
          updated {
            id
            name
            status
          }
        }
      }
      """

      subscribe(
        socket,
        query: campaign_updated_query,
        variables: %{
          "id" => AshGraphql.Resource.encode_relay_id(campaign)
        }
      )

      Campaigns.mark_campaign_successful(campaign)

      assert_push "subscription:data", push

      assert_updated("campaign", campaign_data, push)

      assert campaign_data["id"] ==
               AshGraphql.Resource.encode_relay_id(campaign)

      assert campaign_data["status"] == "FINISHED"
    end

    test "does not receive data for a campaign that was not subscribed to", %{
      socket: socket,
      tenant: tenant
    } do
      subscribed_campaign =
        campaign_with_targets_fixture(2,
          tenant: tenant,
          mechanism_type: :deployment_deploy
        )

      other_campaign =
        campaign_with_targets_fixture(2,
          tenant: tenant,
          mechanism_type: :deployment_deploy
        )

      campaign_updated_query = """
      subscription CampaignUpdated($id: ID!) {
        campaign(id: $id) {
          updated {
            id
            name
            status
          }
        }
      }
      """

      subscribe(
        socket,
        query: campaign_updated_query,
        variables: %{
          "id" => AshGraphql.Resource.encode_relay_id(subscribed_campaign)
        }
      )

      Campaigns.mark_campaign_successful(other_campaign)

      refute_push "subscription:data", _payload, 100
    end

    test "receives data on campaign target update", %{
      socket: socket,
      tenant: tenant
    } do
      campaign =
        1
        |> campaign_with_targets_fixture(
          tenant: tenant,
          mechanism_type: :deployment_deploy
        )
        |> Ash.load!(:campaign_targets)

      [campaign_target] = campaign.campaign_targets

      assert campaign_target.status == :idle

      campaign_updated_query = """
      subscription CampaignUpdated($id: ID!) {
        campaign(id: $id) {
          updated {
            id
            name
            status
            campaignTargets{
              edges{
                node {
                  id
                  status
                }
              }
            }
          }
        }
      }
      """

      subscribe(
        socket,
        query: campaign_updated_query,
        variables: %{
          "id" => AshGraphql.Resource.encode_relay_id(campaign)
        }
      )

      Campaigns.mark_target_as_successful!(campaign_target, tenant: tenant)

      assert_push "subscription:data", push

      assert_updated("campaign", campaign_data, push)

      assert campaign_data["id"] == AshGraphql.Resource.encode_relay_id(campaign)

      [%{"node" => campaign_target}] = campaign_data["campaignTargets"]["edges"]

      assert campaign_target["status"] == "SUCCESSFUL"
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      campaigns{
        created {
          id
        }
        updated {
          id
        }
      }
    }
    """

    query = Keyword.get(opts, :query, default_query)
    variables = Keyword.get(opts, :variables, %{})

    ref = push_doc(socket, query, variables: variables)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end
end
