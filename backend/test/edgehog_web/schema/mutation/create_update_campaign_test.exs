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

defmodule EdgehogWeb.Schema.Mutation.CreateUpdateCampaignTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  describe "createUpdateCampaign mutation" do
    test "creates update_campaign with valid data and at least one target", %{
      conn: conn,
      api_path: api_path
    } do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>)
      update_channel = update_channel_fixture(target_group_ids: [target_group.id])
      base_image = base_image_fixture()

      device =
        device_fixture_compatible_with(base_image)
        |> add_tags(["foobar"])

      rollout_mechanism = %{
        push: %{
          max_failure_percentage: 5.0,
          max_in_progress_updates: 5,
          ota_request_retries: 10,
          ota_request_timeout_seconds: 120,
          force_downgrade: true
        }
      }

      response =
        create_update_campaign_mutation(conn, api_path,
          name: "My Update Campaign",
          base_image_id: base_image.id,
          update_channel_id: update_channel.id,
          rollout_mechanism: rollout_mechanism
        )

      update_campaign = response["data"]["createUpdateCampaign"]["updateCampaign"]
      assert update_campaign["name"] == "My Update Campaign"
      assert update_campaign["status"] == "IDLE"
      assert update_campaign["outcome"] == nil
      assert update_campaign["baseImage"]["version"] == base_image.version
      assert update_campaign["baseImage"]["url"] == base_image.url
      assert update_campaign["updateChannel"]["name"] == update_channel.name
      assert update_campaign["updateChannel"]["handle"] == update_channel.handle
      assert response_rollout_mechanism = update_campaign["rolloutMechanism"]
      assert response_rollout_mechanism["maxFailurePercentage"] == 5.0
      assert response_rollout_mechanism["maxInProgressUpdates"] == 5
      assert response_rollout_mechanism["otaRequestRetries"] == 10
      assert response_rollout_mechanism["otaRequestTimeoutSeconds"] == 120
      assert response_rollout_mechanism["forceDowngrade"] == true
      assert [target] = update_campaign["updateTargets"]
      assert target["status"] == "IDLE"

      assert target["device"]["id"] ==
               Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema)
    end

    test "creates finished update_campaign with valid data and no targets", %{
      conn: conn,
      api_path: api_path
    } do
      response = create_update_campaign_mutation(conn, api_path, name: "My Update Campaign")

      update_campaign = response["data"]["createUpdateCampaign"]["updateCampaign"]
      assert update_campaign["name"] == "My Update Campaign"
      assert update_campaign["status"] == "FINISHED"
      assert update_campaign["outcome"] == "SUCCESS"
      assert update_campaign["updateTargets"] == []
    end

    test "fails when trying to use a non-existing base image", %{conn: conn, api_path: api_path} do
      response = create_update_campaign_mutation(conn, api_path, base_image_id: "123456")

      assert response["data"]["createUpdateCampaign"] == nil
      assert [%{"status_code" => 404, "code" => "not_found"}] = response["errors"]
    end

    test "fails when trying to use a non-existing update channel", %{
      conn: conn,
      api_path: api_path
    } do
      response = create_update_campaign_mutation(conn, api_path, update_channel_id: "123456")

      assert response["data"]["createUpdateCampaign"] == nil
      assert [%{"status_code" => 404, "code" => "not_found"}] = response["errors"]
    end

    test "fails when using an invalid rollout mechanism", %{conn: conn, api_path: api_path} do
      response =
        create_update_campaign_mutation(conn, api_path,
          rollout_mechanism: %{
            push: %{max_failure_percentage: -10.0, max_in_progress_updates: 5}
          }
        )

      assert response["data"]["createUpdateCampaign"] == nil
      assert [%{"status_code" => 422, "message" => message}] = response["errors"]
      assert message =~ "must be greater than or equal to 0"
    end
  end

  @query """
  mutation CreateUpdateCampaign($input: CreateUpdateCampaignInput!) {
    createUpdateCampaign(input: $input) {
      updateCampaign {
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
  }
  """
  defp create_update_campaign_mutation(conn, api_path, opts) do
    {update_channel_id, opts} =
      Keyword.pop_lazy(opts, :update_channel_id, fn ->
        update_channel_fixture()
        |> Map.get(:id)
      end)

    update_channel_id =
      Absinthe.Relay.Node.to_global_id(:update_channel, update_channel_id, EdgehogWeb.Schema)

    {base_image_id, opts} =
      Keyword.pop_lazy(opts, :base_image_id, fn ->
        base_image_fixture()
        |> Map.get(:id)
      end)

    base_image_id =
      Absinthe.Relay.Node.to_global_id(:base_image, base_image_id, EdgehogWeb.Schema)

    {rollout_mechanism, opts} =
      Keyword.pop_lazy(opts, :rollout_mechanism, fn ->
        %{push: %{max_failure_percentage: 10.0, max_in_progress_updates: 10}}
      end)

    input =
      Enum.into(opts, %{
        name: unique_update_campaign_name(),
        base_image_id: base_image_id,
        update_channel_id: update_channel_id,
        rollout_mechanism: rollout_mechanism
      })

    variables = %{input: input}

    conn = post(conn, api_path, query: @query, variables: variables)

    json_response(conn, 200)
  end
end
