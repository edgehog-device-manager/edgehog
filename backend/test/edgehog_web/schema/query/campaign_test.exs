#
# This file is part of Edgehog.
#
# Copyright 2023 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.CampaignTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.Campaign

  describe "campaign query" do
    setup %{tenant: tenant} do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)
      release = release_fixture(tenant: tenant, system_models: 1)
      base_image = base_image_fixture(tenant: tenant)

      device_compatible_with_release =
        [release_id: release.id, online: true, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      device_compatible_with_base_image =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with_base_image()
        |> add_tags(["foobar"])

      context = %{
        channel: channel,
        release: release,
        base_image: base_image,
        device_compatible_with_release: device_compatible_with_release,
        device_compatible_with_base_image: device_compatible_with_base_image
      }

      {:ok, context}
    end

    test "returns firmware_upgrade campaign if present", ctx do
      %{
        channel: channel,
        base_image: base_image,
        device_compatible_with_base_image: device,
        tenant: tenant
      } = ctx

      update_campaign =
        campaign_fixture(
          base_image_id: base_image.id,
          channel_id: channel.id,
          mechanism_type: :firmware_upgrade,
          tenant: tenant
        )

      id = AshGraphql.Resource.encode_relay_id(update_campaign)

      update_campaign_data =
        [tenant: tenant, id: id] |> campaign_query() |> extract_result!()

      assert update_campaign_data["name"] == update_campaign.name
      assert update_campaign_data["status"] == "IDLE"
      assert update_campaign_data["outcome"] == nil

      assert update_campaign_data["campaignMechanism"]["baseImage"]["version"] ==
               base_image.version

      assert update_campaign_data["campaignMechanism"]["baseImage"]["url"] == base_image.url
      assert update_campaign_data["channel"]["name"] == channel.name
      assert update_campaign_data["channel"]["handle"] == channel.handle
      assert response_campaign_mechanism = update_campaign_data["campaignMechanism"]

      assert response_campaign_mechanism["maxFailurePercentage"] ==
               update_campaign.campaign_mechanism.value.max_failure_percentage

      assert response_campaign_mechanism["maxInProgressOperations"] ==
               update_campaign.campaign_mechanism.value.max_in_progress_operations

      assert response_campaign_mechanism["requestRetries"] ==
               update_campaign.campaign_mechanism.value.request_retries

      assert response_campaign_mechanism["requestTimeoutSeconds"] ==
               update_campaign.campaign_mechanism.value.request_timeout_seconds

      assert response_campaign_mechanism["forceDowngrade"] ==
               update_campaign.campaign_mechanism.value.force_downgrade

      assert [target] = extract_nodes!(update_campaign_data["campaignTargets"]["edges"])
      assert target["status"] == "IDLE"

      assert target["device"]["id"] == AshGraphql.Resource.encode_relay_id(device)
    end

    test "returns deployment_deploy campaign if present", ctx do
      %{
        channel: channel,
        release: release,
        device_compatible_with_release: device,
        tenant: tenant
      } = ctx

      deployment_campaign =
        campaign_fixture(
          release_id: release.id,
          channel_id: channel.id,
          mechanism_type: :deployment_deploy,
          tenant: tenant
        )

      id = AshGraphql.Resource.encode_relay_id(deployment_campaign)
      release_id = AshGraphql.Resource.encode_relay_id(release)

      deployment_campaign_data =
        [tenant: tenant, id: id] |> campaign_query() |> extract_result!()

      assert deployment_campaign_data["name"] == deployment_campaign.name
      assert deployment_campaign_data["status"] == "IDLE"
      assert deployment_campaign_data["outcome"] == nil

      assert deployment_campaign_data["campaignMechanism"]["release"]["version"] ==
               release.version

      assert deployment_campaign_data["campaignMechanism"]["release"]["id"] == release_id
      assert deployment_campaign_data["channel"]["name"] == channel.name
      assert deployment_campaign_data["channel"]["handle"] == channel.handle
      assert response_campaign_mechanism = deployment_campaign_data["campaignMechanism"]

      assert response_campaign_mechanism["maxFailurePercentage"] ==
               deployment_campaign.campaign_mechanism.value.max_failure_percentage

      assert response_campaign_mechanism["maxInProgressOperations"] ==
               deployment_campaign.campaign_mechanism.value.max_in_progress_operations

      assert response_campaign_mechanism["requestRetries"] ==
               deployment_campaign.campaign_mechanism.value.request_retries

      assert response_campaign_mechanism["requestTimeoutSeconds"] ==
               deployment_campaign.campaign_mechanism.value.request_timeout_seconds

      assert [target] = extract_nodes!(deployment_campaign_data["campaignTargets"]["edges"])
      assert target["status"] == "IDLE"

      assert target["device"]["id"] == AshGraphql.Resource.encode_relay_id(device)
    end

    test "returns deployment_start campaign if present", ctx do
      %{
        channel: channel,
        release: release,
        tenant: tenant
      } = ctx

      deployment_campaign =
        campaign_fixture(
          release_id: release.id,
          channel_id: channel.id,
          mechanism_type: :deployment_start,
          deploy_for_required_operations: true,
          tenant: tenant
        )

      id = AshGraphql.Resource.encode_relay_id(deployment_campaign)
      release_id = AshGraphql.Resource.encode_relay_id(release)

      deployment_campaign_data =
        [tenant: tenant, id: id] |> campaign_query() |> extract_result!()

      assert deployment_campaign_data["name"] == deployment_campaign.name
      assert deployment_campaign_data["status"] == "IDLE"
      assert deployment_campaign_data["campaignMechanism"]["release"]["id"] == release_id
    end

    test "returns deployment_stop campaign if present", ctx do
      %{
        channel: channel,
        release: release,
        tenant: tenant
      } = ctx

      deployment_campaign =
        campaign_fixture(
          release_id: release.id,
          channel_id: channel.id,
          mechanism_type: :deployment_stop,
          deploy_for_required_operations: true,
          tenant: tenant
        )

      id = AshGraphql.Resource.encode_relay_id(deployment_campaign)
      release_id = AshGraphql.Resource.encode_relay_id(release)

      deployment_campaign_data =
        [tenant: tenant, id: id] |> campaign_query() |> extract_result!()

      assert deployment_campaign_data["name"] == deployment_campaign.name
      assert deployment_campaign_data["status"] == "IDLE"
      assert deployment_campaign_data["campaignMechanism"]["release"]["id"] == release_id
    end

    test "returns deployment_delete campaign if present", ctx do
      %{
        channel: channel,
        release: release,
        tenant: tenant
      } = ctx

      deployment_campaign =
        campaign_fixture(
          release_id: release.id,
          channel_id: channel.id,
          mechanism_type: :deployment_delete,
          deploy_for_required_operations: true,
          tenant: tenant
        )

      id = AshGraphql.Resource.encode_relay_id(deployment_campaign)
      release_id = AshGraphql.Resource.encode_relay_id(release)

      deployment_campaign_data =
        [tenant: tenant, id: id] |> campaign_query() |> extract_result!()

      assert deployment_campaign_data["name"] == deployment_campaign.name
      assert deployment_campaign_data["status"] == "IDLE"
      assert deployment_campaign_data["campaignMechanism"]["release"]["id"] == release_id
    end

    test "returns deployment_upgrade campaign if present", ctx do
      %{
        channel: channel,
        release: release,
        tenant: tenant
      } = ctx

      release = Ash.load!(release, [:application, :system_models], tenant: tenant)

      target_release =
        release_fixture(
          application_id: release.application.id,
          version: "2.0.0",
          required_system_models: release.system_models,
          tenant: tenant
        )

      deployment_campaign =
        campaign_fixture(
          release_id: release.id,
          target_release_id: target_release.id,
          channel_id: channel.id,
          mechanism_type: :deployment_upgrade,
          deploy_for_required_operations: true,
          tenant: tenant
        )

      id = AshGraphql.Resource.encode_relay_id(deployment_campaign)
      release_id = AshGraphql.Resource.encode_relay_id(release)
      target_release_id = AshGraphql.Resource.encode_relay_id(target_release)

      deployment_campaign_data =
        [tenant: tenant, id: id] |> campaign_query() |> extract_result!()

      assert deployment_campaign_data["name"] == deployment_campaign.name
      assert deployment_campaign_data["status"] == "IDLE"
      assert deployment_campaign_data["campaignMechanism"]["release"]["id"] == release_id

      assert deployment_campaign_data["campaignMechanism"]["targetRelease"]["id"] ==
               target_release_id
    end

    test "returns nil if non existing", %{tenant: tenant} do
      id = non_existing_update_campaign_id(tenant)

      result = campaign_query(tenant: tenant, id: id)

      assert result == %{data: %{"campaign" => nil}}
    end

    test "returns all campaignTarget fields", %{tenant: tenant} do
      now = DateTime.utc_now()

      target =
        [now: now, tenant: tenant, mechanism_type: :firmware_upgrade]
        |> successful_target_fixture()
        |> Ash.load!([:campaign, :ota_operation])

      update_campaign_id = AshGraphql.Resource.encode_relay_id(target.campaign)

      document = """
      query ($id: ID!) {
        campaign(id: $id) {
          campaignTargets {
            edges {
              node {
                id
                status
                retryCount
                latestAttempt
                completionTimestamp
                otaOperation {
                  id
                }
              }
            }
          }
        }
      }
      """

      update_campaign_data =
        [document: document, id: update_campaign_id, tenant: tenant]
        |> campaign_query()
        |> extract_result!()

      assert [update_target] = extract_nodes!(update_campaign_data["campaignTargets"]["edges"])

      assert update_target["id"] == AshGraphql.Resource.encode_relay_id(target)
      assert update_target["status"] == "SUCCESSFUL"
      assert update_target["retryCount"] == 0
      assert update_target["latestAttempt"] == DateTime.to_iso8601(now)
      assert update_target["completionTimestamp"] == DateTime.to_iso8601(now)

      assert update_target["otaOperation"]["id"] ==
               AshGraphql.Resource.encode_relay_id(target.ota_operation)
    end
  end

  describe "updateCampaign stats" do
    defp update_target_status!(target, :in_progress) do
      Campaigns.mark_target_as_in_progress(target)
    end

    defp update_target_status!(target, :failed) do
      Campaigns.mark_target_as_failed(target)
    end

    defp update_target_status!(target, :successful) do
      Campaigns.mark_target_as_successful(target)
    end

    defp campaign_for_stats_fixture(tenant) do
      target_count = Enum.random(20..40)

      update_campaign =
        target_count
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      # Pick some targets to be put in a different status
      in_progress_target_count = Enum.random(0..5)
      failed_target_count = Enum.random(0..5)
      successful_target_count = Enum.random(0..5)

      idle_target_count =
        target_count - in_progress_target_count - failed_target_count - successful_target_count

      {in_progress, rest} = Enum.split(update_campaign.campaign_targets, in_progress_target_count)
      {failed, rest} = Enum.split(rest, failed_target_count)
      {successful, rest} = Enum.split(rest, successful_target_count)
      assert length(rest) == idle_target_count

      # Update the target status
      for {targets, status} <- [
            {in_progress, :in_progress},
            {failed, :failed},
            {successful, :successful}
          ],
          target <- targets do
        update_target_status!(target, status)
      end

      # Re-read the update campaign from the database so we have the targets with the updated status
      Ash.get!(Campaign, update_campaign.id, tenant: tenant, load: :campaign_targets)
    end

    test "returns update campaign stats", %{tenant: tenant} do
      update_campaign = campaign_for_stats_fixture(tenant)

      document = """
      query ($id: ID!) {
        campaign(id: $id) {
          totalTargetCount
          idleTargetCount
          inProgressTargetCount
          failedTargetCount
          successfulTargetCount
        }
      }
      """

      update_campaign_id = AshGraphql.Resource.encode_relay_id(update_campaign)

      update_campaign_data =
        [document: document, id: update_campaign_id, tenant: tenant]
        |> campaign_query()
        |> extract_result!()

      targets = update_campaign.campaign_targets

      assert update_campaign_data["totalTargetCount"] == length(targets)
      assert update_campaign_data["idleTargetCount"] == Enum.count(targets, &(&1.status == :idle))

      assert update_campaign_data["inProgressTargetCount"] ==
               Enum.count(targets, &(&1.status == :in_progress))

      assert update_campaign_data["failedTargetCount"] ==
               Enum.count(targets, &(&1.status == :failed))

      assert update_campaign_data["successfulTargetCount"] ==
               Enum.count(targets, &(&1.status == :successful))
    end
  end

  defp campaign_query(opts) do
    default_document = """
    query ($id: ID!) {
      campaign(id: $id) {
        name
        status
        outcome
        campaignMechanism {
          ... on FirmwareUpgrade {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            forceDowngrade
            baseImage {
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
              version
              application {
                id
                name
              }
            }
          }
          ... on DeploymentStart {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
            }
          }
          ... on DeploymentStop {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
            }
          }
          ... on DeploymentDelete {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
            }
          }
          ... on DeploymentUpgrade {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            release {
              id
              version
            }
            targetRelease {
              id
              version
            }
          }
        }
        channel {
          name
          handle
        }
        campaignTargets {
          edges {
            node {
              status
              device {
                id
              }
            }
          }
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables = %{"id" => id}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "campaign" => update_campaign
             }
           } = result

    refute Map.get(result, :errors)

    assert update_campaign

    update_campaign
  end

  defp non_existing_update_campaign_id(tenant) do
    fixture = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture)

    id
  end

  defp extract_nodes!(data) do
    Enum.map(data, &Map.fetch!(&1, "node"))
  end
end
