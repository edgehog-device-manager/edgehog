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

defmodule EdgehogWeb.Schema.Query.UpdateCampaignsTest do
  use EdgehogWeb.ConnCase

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  describe "updateCampaigns query" do
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

    test "returns empty update campaigns", %{conn: conn, api_path: api_path} do
      response = update_campaigns_query(conn, api_path)
      assert response["data"]["updateCampaigns"] == []
    end

    test "returns update campaigns if present", ctx do
      %{
        conn: conn,
        api_path: api_path,
        update_channel: update_channel,
        base_image: base_image,
        device: device
      } = ctx

      update_campaign =
        update_campaign_fixture(base_image: base_image, update_channel: update_channel)

      response = update_campaigns_query(conn, api_path)

      [update_campaign_data] = response["data"]["updateCampaigns"]

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

    test "returns all UpdateTarget fields", ctx do
      %{
        conn: conn,
        api_path: api_path
      } = ctx

      now = DateTime.utc_now()
      target = failed_target_fixture(now: now)

      query = """
      query {
        updateCampaigns {
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

      response = update_campaigns_query(conn, api_path, query: query)

      assert [update_campaign_data] = response["data"]["updateCampaigns"]
      assert [update_target] = update_campaign_data["updateTargets"]

      assert {:ok, %{id: update_target_id, type: :update_target}} =
               update_target["id"]
               |> Absinthe.Relay.Node.from_global_id(EdgehogWeb.Schema)

      assert to_string(target.id) == update_target_id
      assert update_target["status"] == "FAILED"
      assert update_target["retryCount"] == 0
      assert update_target["latestAttempt"] == DateTime.to_iso8601(now)
      assert update_target["completionTimestamp"] == DateTime.to_iso8601(now)

      assert {:ok, %{id: ota_operation_id, type: :ota_operation}} =
               update_target["otaOperation"]["id"]
               |> Absinthe.Relay.Node.from_global_id(EdgehogWeb.Schema)

      assert ota_operation_id == target.ota_operation_id
    end
  end

  @query """
  query {
    updateCampaigns {
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
  defp update_campaigns_query(conn, api_path, opts \\ []) do
    query = Keyword.get(opts, :query, @query)
    conn = get(conn, api_path, query: query)

    json_response(conn, 200)
  end
end
