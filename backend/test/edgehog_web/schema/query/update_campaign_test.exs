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

defmodule EdgehogWeb.Schema.Query.UpdateCampaignTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Edgehog.UpdateCampaigns.UpdateCampaign

  describe "updateCampaign query" do
    setup do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>)
      update_channel = update_channel_fixture(target_group_ids: [target_group.id])
      base_image = base_image_fixture()

      device =
        device_fixture_compatible_with(base_image)
        |> add_tags(["foobar"])

      context = %{
        update_channel: update_channel,
        base_image: base_image,
        device: device
      }

      {:ok, context}
    end

    test "returns update campaign if present", ctx do
      %{
        conn: conn,
        api_path: api_path,
        update_channel: update_channel,
        base_image: base_image,
        device: device
      } = ctx

      update_campaign =
        update_campaign_fixture(base_image: base_image, update_channel: update_channel)

      response = update_campaign_query(conn, api_path, update_campaign)

      update_campaign_data = response["data"]["updateCampaign"]

      assert update_campaign_data["name"] == update_campaign.name
      assert update_campaign_data["status"] == "IDLE"
      assert update_campaign_data["outcome"] == nil
      assert update_campaign_data["baseImage"]["version"] == base_image.version
      assert update_campaign_data["baseImage"]["url"] == base_image.url
      assert update_campaign_data["updateChannel"]["name"] == update_channel.name
      assert update_campaign_data["updateChannel"]["handle"] == update_channel.handle
      assert response_rollout_mechanism = update_campaign_data["rolloutMechanism"]

      assert response_rollout_mechanism["maxFailurePercentage"] ==
               update_campaign.rollout_mechanism.max_failure_percentage

      assert response_rollout_mechanism["maxInProgressUpdates"] ==
               update_campaign.rollout_mechanism.max_in_progress_updates

      assert response_rollout_mechanism["otaRequestRetries"] ==
               update_campaign.rollout_mechanism.ota_request_retries

      assert response_rollout_mechanism["otaRequestTimeoutSeconds"] ==
               update_campaign.rollout_mechanism.ota_request_timeout_seconds

      assert response_rollout_mechanism["forceDowngrade"] ==
               update_campaign.rollout_mechanism.force_downgrade

      assert [target] = update_campaign_data["updateTargets"]
      assert target["status"] == "IDLE"

      assert target["device"]["id"] ==
               Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema)
    end

    test "returns not found if non existing", %{conn: conn, api_path: api_path} do
      response = update_campaign_query(conn, api_path, 1_234_567)
      assert response["data"]["updateCampaign"] == nil
      assert [%{"code" => "not_found", "status_code" => 404}] = response["errors"]
    end

    test "returns all UpdateTarget fields", ctx do
      %{
        conn: conn,
        api_path: api_path
      } = ctx

      now = DateTime.utc_now()
      target = successful_target_fixture(now: now)
      update_campaign_id = target.update_campaign_id

      query = """
      query ($id: ID!) {
        updateCampaign(id: $id) {
          updateTargets {
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
      """

      response = update_campaign_query(conn, api_path, update_campaign_id, query: query)

      assert [update_target] = response["data"]["updateCampaign"]["updateTargets"]

      assert {:ok, %{id: update_target_id, type: :update_target}} =
               update_target["id"]
               |> Absinthe.Relay.Node.from_global_id(EdgehogWeb.Schema)

      assert to_string(target.id) == update_target_id
      assert update_target["status"] == "SUCCESSFUL"
      assert update_target["retryCount"] == 0
      assert update_target["latestAttempt"] == DateTime.to_iso8601(now)
      assert update_target["completionTimestamp"] == DateTime.to_iso8601(now)

      assert {:ok, %{id: ota_operation_id, type: :ota_operation}} =
               update_target["otaOperation"]["id"]
               |> Absinthe.Relay.Node.from_global_id(EdgehogWeb.Schema)

      assert ota_operation_id == target.ota_operation_id
    end
  end

  describe "updateCampaign stats field" do
    defp update_target_status!(target, status) do
      Ecto.Changeset.change(target, status: status)
      |> Edgehog.Repo.update!()
    end

    defp update_campaign_for_stats_fixture do
      target_count = Enum.random(20..40)

      update_campaign = update_campaign_with_targets_fixture(target_count)

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
      {:ok, update_campaign} = Edgehog.UpdateCampaigns.fetch_update_campaign(update_campaign.id)

      update_campaign
    end

    test "returns update campaign stats", ctx do
      %{
        conn: conn,
        api_path: api_path
      } = ctx

      update_campaign = update_campaign_for_stats_fixture()

      query = """
      query ($id: ID!) {
        updateCampaign(id: $id) {
          stats {
            totalTargetCount
            idleTargetCount
            inProgressTargetCount
            failedTargetCount
            successfulTargetCount
          }
        }
      }
      """

      response = update_campaign_query(conn, api_path, update_campaign, query: query)

      assert stats = response["data"]["updateCampaign"]["stats"]

      targets = update_campaign.update_targets

      assert stats["totalTargetCount"] == length(targets)
      assert stats["idleTargetCount"] == Enum.count(targets, &(&1.status == :idle))
      assert stats["inProgressTargetCount"] == Enum.count(targets, &(&1.status == :in_progress))
      assert stats["failedTargetCount"] == Enum.count(targets, &(&1.status == :failed))
      assert stats["successfulTargetCount"] == Enum.count(targets, &(&1.status == :successful))
    end
  end

  @query """
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
      updateChannel {
        name
        handle
      }
      updateTargets {
        status
        device {
          id
        }
      }
    }
  }
  """
  defp update_campaign_query(conn, api_path, target, opts \\ [])

  defp update_campaign_query(conn, api_path, %UpdateCampaign{} = update_campaign, opts) do
    update_campaign_query(conn, api_path, update_campaign.id, opts)
  end

  defp update_campaign_query(conn, api_path, id, opts) do
    id = Absinthe.Relay.Node.to_global_id(:update_campaign, id, EdgehogWeb.Schema)

    variables = %{id: id}
    query = Keyword.get(opts, :query, @query)
    conn = get(conn, api_path, query: query, variables: variables)

    json_response(conn, 200)
  end
end
