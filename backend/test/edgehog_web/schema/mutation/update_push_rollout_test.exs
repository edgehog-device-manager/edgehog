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

defmodule EdgehogWeb.Schema.Mutation.UpdatePushRolloutTest do
  use EdgehogWeb.ConnCase

  import Edgehog.UpdateCampaignsFixtures

  describe "updatePushRollout mutation" do
    setup do
      {:ok, update_campaign: update_campaign_fixture()}
    end

    test "updates the push rollout with valid data", %{
      conn: conn,
      api_path: api_path,
      update_campaign: update_campaign
    } do
      update_data = %{
        max_in_progress_updates: update_campaign.rollout_mechanism.max_in_progress_updates + 1
      }

      mutation_opts =
        update_data
        |> Map.put(:update_campaign_id, update_campaign.id)
        |> Keyword.new()

      response = update_push_rollout_mutation(conn, api_path, mutation_opts)

      updated_update_campaign = response["data"]["updatePushRollout"]["updateCampaign"]
      assert updated_update_campaign["name"] == update_campaign.name

      assert updated_update_campaign["rolloutMechanism"]["maxInProgressUpdates"] ==
               update_data.max_in_progress_updates
    end

    test "fails when trying to use a non-existing update campaign", %{
      conn: conn,
      api_path: api_path
    } do
      non_existing_id = "123456"
      args = [update_campaign_id: non_existing_id, max_in_progress_updates: 10]
      response = update_push_rollout_mutation(conn, api_path, args)

      assert %{"errors" => [%{"status_code" => 404, "code" => "not_found"}]} = response
    end
  end

  @query """
  mutation UpdatePushRollout($input: UpdatePushRolloutInput!) {
    updatePushRollout(input: $input) {
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
  defp update_push_rollout_mutation(conn, api_path, opts) do
    input =
      opts
      |> Keyword.update!(
        :update_campaign_id,
        &Absinthe.Relay.Node.to_global_id(:update_campaign, &1, EdgehogWeb.Schema)
      )
      |> Map.new()

    variables = %{input: input}

    conn = post(conn, api_path, query: @query, variables: variables)

    json_response(conn, 200)
  end
end
