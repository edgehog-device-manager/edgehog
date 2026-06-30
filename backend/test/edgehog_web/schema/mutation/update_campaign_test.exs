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

defmodule EdgehogWeb.Schema.Mutation.UpdateCampaignTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.BaseImagesFixtures

  alias Edgehog.Campaigns

  describe "update campaign mutation" do
    setup %{tenant: tenant} do
      mock_scheduled_campaign = fn type ->
        [tenant: tenant, mechanism_type: type]
        |> campaign_fixture()
        |> Campaigns.mark_campaign_scheduled!(tenant: tenant)
      end

      deployment_deploy_campaign = mock_scheduled_campaign.(:deployment_deploy)
      deployment_upgrade_campaign = mock_scheduled_campaign.(:deployment_upgrade)
      firmware_upgrade_campaign = mock_scheduled_campaign.(:firmware_upgrade)

      {:ok,
       campaign: deployment_deploy_campaign,
       deployment_deploy_campaign: deployment_deploy_campaign,
       deployment_upgrade_campaign: deployment_upgrade_campaign,
       firmware_upgrade_campaign: firmware_upgrade_campaign}
    end

    test "updates common campaign fields", %{deployment_deploy_campaign: campaign, tenant: tenant} do
      id = AshGraphql.Resource.encode_relay_id(campaign)

      timestamp = DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_iso8601()

      updated_campaign =
        [
          id: id,
          max_in_progress_operations: 10,
          request_retries: 5,
          request_timeout_seconds: 120,
          max_failure_percentage: 20,
          scheduled_at_timestamp: timestamp,
          tenant: tenant
        ]
        |> update_campaign_mutation()
        |> extract_result!()

      assert updated_campaign["campaignMechanism"]["maxInProgressOperations"] == 10
      assert updated_campaign["campaignMechanism"]["requestRetries"] == 5
      assert updated_campaign["campaignMechanism"]["requestTimeoutSeconds"] == 120
      assert updated_campaign["campaignMechanism"]["maxFailurePercentage"] == 20
      assert updated_campaign["scheduledAtTimestamp"] == timestamp
    end

    test "updates a deployment_deploy campaign specific fields", %{
      deployment_deploy_campaign: campaign,
      tenant: tenant
    } do
      id = AshGraphql.Resource.encode_relay_id(campaign)
      different_release = release_fixture(tenant: tenant)
      release_id = AshGraphql.Resource.encode_relay_id(different_release)

      updated_campaign =
        [
          id: id,
          releaseId: release_id,
          tenant: tenant
        ]
        |> update_campaign_mutation()
        |> extract_result!()

      assert updated_campaign["campaignMechanism"]["release"]["id"] == release_id
    end

    test "updates a firmware_upgrade campaign specific fields", %{
      firmware_upgrade_campaign: campaign,
      tenant: tenant
    } do
      id = AshGraphql.Resource.encode_relay_id(campaign)
      different_base_image = base_image_fixture(tenant: tenant)
      different_base_image_id = AshGraphql.Resource.encode_relay_id(different_base_image)

      updated_campaign =
        [
          id: id,
          base_image_id: different_base_image_id,
          tenant: tenant
        ]
        |> update_campaign_mutation()
        |> extract_result!()

      assert updated_campaign["campaignMechanism"]["baseImage"]["id"] == different_base_image_id
    end

    test "updates a deployment_upgrade campaign specific fields", %{
      deployment_upgrade_campaign: campaign,
      tenant: tenant
    } do
      id = AshGraphql.Resource.encode_relay_id(campaign)
      target_release = release_fixture(tenant: tenant)
      target_release_id = AshGraphql.Resource.encode_relay_id(target_release)

      updated_campaign =
        [
          id: id,
          target_release_id: target_release_id,
          tenant: tenant
        ]
        |> update_campaign_mutation()
        |> extract_result!()

      assert updated_campaign["campaignMechanism"]["targetRelease"]["id"] == target_release_id
    end

    test "ignores fields that are not relevant for the campaign mechanism type", %{
      deployment_deploy_campaign: campaign,
      tenant: tenant
    } do
      id = AshGraphql.Resource.encode_relay_id(campaign)
      different_base_image = base_image_fixture(tenant: tenant)
      different_base_image_id = AshGraphql.Resource.encode_relay_id(different_base_image)

      updated_campaign =
        [
          id: id,
          base_image_id: different_base_image_id,
          tenant: tenant
        ]
        |> update_campaign_mutation()
        |> extract_result!()

      assert is_nil(updated_campaign["campaignMechanism"]["baseImage"])
    end

    test "returns an error when trying to update a non-existent campaign", %{tenant: tenant} do
      non_existent_campaign_id = non_existing_campaign_id(tenant)

      result =
        [
          id: non_existent_campaign_id,
          max_in_progress_operations: 10,
          tenant: tenant
        ]
        |> update_campaign_mutation()
        |> extract_error!()

      assert result.message == "could not be found"
    end

    test "returns an error when trying to update a campaign that has already started", %{
      deployment_deploy_campaign: campaign,
      tenant: tenant
    } do
      id = AshGraphql.Resource.encode_relay_id(campaign)

      # Mark the campaign as in_progress to simulate a started campaign
      Campaigns.mark_campaign_in_progress!(campaign, tenant: tenant)

      result =
        [
          id: id,
          max_in_progress_operations: 10,
          tenant: tenant
        ]
        |> update_campaign_mutation()
        |> extract_error!()

      assert result.message == "Only scheduled campaigns can be updated"
    end
  end

  defp update_campaign_mutation(opts) do
    default_document = """
    mutation UpdateCampaign($id: ID!, $input: UpdateCampaignInput!) {
      updateCampaign(id: $id, input: $input) {
        result {
          id
          scheduledAtTimestamp
          campaignMechanism {
            ... on FirmwareUpgrade {
              maxFailurePercentage
              maxInProgressOperations
              requestRetries
              requestTimeoutSeconds
              forceDowngrade
              baseImage {
                id
                version
                url
              }
            }
            ... on DeploymentDeploy {
              maxFailurePercentage
              maxInProgressOperations
              requestRetries
              requestTimeoutSeconds
              release {
                id
              }
            }
            ... on DeploymentUpgrade {
              maxFailurePercentage
              maxInProgressOperations
              requestRetries
              requestTimeoutSeconds
              release {
                id
              }
              targetRelease {
                id
              }
            }
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    input =
      %{
        "name" => Keyword.get(opts, :name),
        "releaseId" => Keyword.get(opts, :releaseId),
        "scheduledAtTimestamp" => Keyword.get(opts, :scheduled_at_timestamp),
        "maxFailurePercentage" => Keyword.get(opts, :max_failure_percentage),
        "maxInProgressOperations" => Keyword.get(opts, :max_in_progress_operations),
        "requestRetries" => Keyword.get(opts, :request_retries),
        "requestTimeoutSeconds" => Keyword.get(opts, :request_timeout_seconds),
        "fileId" => Keyword.get(opts, :file_id),
        "baseImageId" => Keyword.get(opts, :base_image_id),
        "targetReleaseId" => Keyword.get(opts, :target_release_id)
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Map.new()

    variables = %{"id" => id, "input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["updateCampaign"])
    assert %{errors: [error]} = result
    error
  end

  defp extract_result!(result) do
    assert %{data: %{"updateCampaign" => %{"result" => campaign}}} = result
    refute Map.get(result, :errors)
    assert campaign
    campaign
  end

  defp non_existing_campaign_id(tenant) do
    fixture = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture, action: :destroy_fixture)

    id
  end
end
