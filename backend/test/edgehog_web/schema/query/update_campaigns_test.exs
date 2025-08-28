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

defmodule EdgehogWeb.Schema.Query.UpdateCampaignsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  describe "updateCampaigns query" do
    setup %{tenant: tenant} do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)
      update_channel = update_channel_fixture(target_group_ids: [target_group.id], tenant: tenant)
      base_image = base_image_fixture(tenant: tenant)

      device =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with()
        |> add_tags(["foobar"])

      context = %{
        update_channel: update_channel,
        base_image: base_image,
        device: device
      }

      {:ok, context}
    end

    test "returns empty update campaigns", %{tenant: tenant} do
      assert [] == [tenant: tenant] |> update_campaigns_query() |> extract_result!()
    end

    test "returns update campaigns if present", ctx do
      %{
        tenant: tenant,
        update_channel: update_channel,
        base_image: base_image,
        device: device
      } = ctx

      update_campaign =
        update_campaign_fixture(
          base_image_id: base_image.id,
          update_channel_id: update_channel.id,
          tenant: tenant
        )

      [update_campaign_data] =
        [tenant: tenant] |> update_campaigns_query() |> extract_result!() |> extract_nodes!()

      assert update_campaign_data["name"] == update_campaign.name
      assert update_campaign_data["status"] == "IDLE"
      assert update_campaign_data["outcome"] == nil
      assert update_campaign_data["baseImage"]["version"] == base_image.version
      assert update_campaign_data["baseImage"]["url"] == base_image.url
      assert update_campaign_data["updateChannel"]["name"] == update_channel.name
      assert update_campaign_data["updateChannel"]["handle"] == update_channel.handle
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

    test "returns all UpdateTarget fields", %{tenant: tenant} do
      now = DateTime.utc_now()
      target = [now: now, tenant: tenant] |> failed_target_fixture() |> Ash.load!(:ota_operation)

      document = """
      query {
        updateCampaigns {
          edges {
            node {
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
        }
      }
      """

      [update_campaign_data] =
        [document: document, tenant: tenant]
        |> update_campaigns_query()
        |> extract_result!()
        |> extract_nodes!()

      assert [update_target] = extract_nodes!(update_campaign_data["updateTargets"]["edges"])

      assert update_target["id"] == AshGraphql.Resource.encode_relay_id(target)
      assert update_target["status"] == "FAILED"
      assert update_target["retryCount"] == 0
      assert update_target["latestAttempt"] == DateTime.to_iso8601(now)
      assert update_target["completionTimestamp"] == DateTime.to_iso8601(now)

      assert update_target["otaOperation"]["id"] ==
               AshGraphql.Resource.encode_relay_id(target.ota_operation)
    end
  end

  defp update_campaigns_query(opts) do
    default_document = """
    query {
      updateCampaigns {
        edges {
          node {
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
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateCampaigns" => %{
                 "edges" => update_campaigns
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert update_campaigns != nil

    update_campaigns
  end

  defp extract_nodes!(data) do
    Enum.map(data, &Map.fetch!(&1, "node"))
  end
end
