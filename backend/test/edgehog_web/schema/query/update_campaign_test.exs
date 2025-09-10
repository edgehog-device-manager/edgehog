#
# This file is part of Edgehog.
#
# Copyright 2023 - 2025 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.UpdateCampaignTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.CampaignsFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Edgehog.UpdateCampaigns.UpdateCampaign

  describe "updateCampaign query" do
    setup %{tenant: tenant} do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)
      base_image = base_image_fixture(tenant: tenant)

      device =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with_base_image()
        |> add_tags(["foobar"])

      context = %{
        channel: channel,
        base_image: base_image,
        device: device
      }

      {:ok, context}
    end

    test "returns update campaign if present", ctx do
      %{
        channel: channel,
        base_image: base_image,
        device: device,
        tenant: tenant
      } = ctx

      update_campaign =
        update_campaign_fixture(
          base_image_id: base_image.id,
          channel_id: channel.id,
          tenant: tenant
        )

      id = AshGraphql.Resource.encode_relay_id(update_campaign)

      update_campaign_data =
        [tenant: tenant, id: id] |> update_campaign_query() |> extract_result!()

      assert update_campaign_data["name"] == update_campaign.name
      assert update_campaign_data["status"] == "IDLE"
      assert update_campaign_data["outcome"] == nil
      assert update_campaign_data["baseImage"]["version"] == base_image.version
      assert update_campaign_data["baseImage"]["url"] == base_image.url
      assert update_campaign_data["channel"]["name"] == channel.name
      assert update_campaign_data["channel"]["handle"] == channel.handle
      assert response_rollout_mechanism = update_campaign_data["rolloutMechanism"]

      assert response_rollout_mechanism["maxFailurePercentage"] ==
               update_campaign.rollout_mechanism.value.max_failure_percentage

      assert response_rollout_mechanism["maxInProgressUpdates"] ==
               update_campaign.rollout_mechanism.value.max_in_progress_updates

      assert response_rollout_mechanism["otaRequestRetries"] ==
               update_campaign.rollout_mechanism.value.ota_request_retries

      assert response_rollout_mechanism["otaRequestTimeoutSeconds"] ==
               update_campaign.rollout_mechanism.value.ota_request_timeout_seconds

      assert response_rollout_mechanism["forceDowngrade"] ==
               update_campaign.rollout_mechanism.value.force_downgrade

      assert [target] = extract_nodes!(update_campaign_data["updateTargets"]["edges"])
      assert target["status"] == "IDLE"

      assert target["device"]["id"] == AshGraphql.Resource.encode_relay_id(device)
    end

    test "returns nil if non existing", %{tenant: tenant} do
      id = non_existing_update_campaign_id(tenant)

      result = update_campaign_query(tenant: tenant, id: id)

      assert result == %{data: %{"updateCampaign" => nil}}
    end

    test "returns all UpdateTarget fields", %{tenant: tenant} do
      now = DateTime.utc_now()

      target =
        [now: now, tenant: tenant]
        |> successful_target_fixture()
        |> Ash.load!([:update_campaign, :ota_operation])

      update_campaign_id = AshGraphql.Resource.encode_relay_id(target.update_campaign)

      document = """
      query ($id: ID!) {
        updateCampaign(id: $id) {
          updateTargets {
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
        |> update_campaign_query()
        |> extract_result!()

      assert [update_target] = extract_nodes!(update_campaign_data["updateTargets"]["edges"])

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
    alias Edgehog.UpdateCampaigns

    defp update_target_status!(target, :in_progress) do
      UpdateCampaigns.mark_target_as_in_progress(target)
    end

    defp update_target_status!(target, :failed) do
      UpdateCampaigns.mark_target_as_failed(target)
    end

    defp update_target_status!(target, :successful) do
      UpdateCampaigns.mark_target_as_successful(target)
    end

    defp update_campaign_for_stats_fixture(tenant) do
      target_count = Enum.random(20..40)

      update_campaign =
        target_count
        |> update_campaign_with_targets_fixture(tenant: tenant)
        |> Ash.load!(:update_targets)

      # Pick some targets to be put in a different status
      in_progress_target_count = Enum.random(0..5)
      failed_target_count = Enum.random(0..5)
      successful_target_count = Enum.random(0..5)

      idle_target_count =
        target_count - in_progress_target_count - failed_target_count - successful_target_count

      {in_progress, rest} = Enum.split(update_campaign.update_targets, in_progress_target_count)
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
      Ash.get!(UpdateCampaign, update_campaign.id, tenant: tenant, load: :update_targets)
    end

    test "returns update campaign stats", %{tenant: tenant} do
      update_campaign = update_campaign_for_stats_fixture(tenant)

      document = """
      query ($id: ID!) {
        updateCampaign(id: $id) {
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
        |> update_campaign_query()
        |> extract_result!()

      targets = update_campaign.update_targets

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

  defp update_campaign_query(opts) do
    default_document = """
    query ($id: ID!) {
      updateCampaign(id: $id) {
        name
        status
        outcome
        rolloutMechanism {
          ... on PushRollout {
            maxFailurePercentage
            maxInProgressUpdates
            otaRequestRetries
            otaRequestTimeoutSeconds
            forceDowngrade
          }
        }
        baseImage {
          version
          url
        }
        channel {
          name
          handle
        }
        updateTargets {
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
               "updateCampaign" => update_campaign
             }
           } = result

    refute Map.get(result, :errors)

    assert update_campaign != nil

    update_campaign
  end

  defp non_existing_update_campaign_id(tenant) do
    fixture = update_campaign_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture)

    id
  end

  defp extract_nodes!(data) do
    Enum.map(data, &Map.fetch!(&1, "node"))
  end
end
