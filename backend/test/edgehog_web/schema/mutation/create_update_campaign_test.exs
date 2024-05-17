#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
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
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  @moduletag :ported_to_ash

  describe "createUpdateCampaign mutation" do
    test "creates update_campaign with valid data and at least one target", %{tenant: tenant} do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)
      update_channel = update_channel_fixture(target_group_ids: [target_group.id], tenant: tenant)
      base_image = base_image_fixture(tenant: tenant)

      device =
        device_fixture_compatible_with(base_image_id: base_image.id, tenant: tenant)
        |> add_tags(["foobar"])

      rollout_mechanism = %{
        "push" => %{
          "maxFailurePercentage" => 5.0,
          "maxInProgressUpdates" => 5,
          "otaRequestRetries" => 10,
          "otaRequestTimeoutSeconds" => 120,
          "forceDowngrade" => true
        }
      }

      base_image_id = AshGraphql.Resource.encode_relay_id(base_image)
      update_channel_id = AshGraphql.Resource.encode_relay_id(update_channel)

      update_campaign_data =
        create_update_campaign_mutation(
          name: "My Update Campaign",
          base_image_id: base_image_id,
          update_channel_id: update_channel_id,
          rollout_mechanism: rollout_mechanism,
          tenant: tenant
        )
        |> extract_result!()

      assert update_campaign_data["name"] == "My Update Campaign"
      assert update_campaign_data["status"] == "IDLE"
      assert update_campaign_data["outcome"] == nil
      assert update_campaign_data["baseImage"]["id"] == base_image_id
      assert update_campaign_data["baseImage"]["version"] == base_image.version
      assert update_campaign_data["baseImage"]["url"] == base_image.url
      assert update_campaign_data["updateChannel"]["id"] == update_channel_id
      assert update_campaign_data["updateChannel"]["name"] == update_channel.name
      assert update_campaign_data["updateChannel"]["handle"] == update_channel.handle
      assert rollout_mechanism_data = update_campaign_data["rolloutMechanism"]
      assert rollout_mechanism_data["maxFailurePercentage"] == 5.0
      assert rollout_mechanism_data["maxInProgressUpdates"] == 5
      assert rollout_mechanism_data["otaRequestRetries"] == 10
      assert rollout_mechanism_data["otaRequestTimeoutSeconds"] == 120
      assert rollout_mechanism_data["forceDowngrade"] == true
      assert [target_data] = update_campaign_data["updateTargets"]
      assert target_data["status"] == "IDLE"
      assert target_data["device"]["id"] == AshGraphql.Resource.encode_relay_id(device)
    end

    test "creates finished update_campaign with valid data and no targets", %{tenant: tenant} do
      update_campaign_data =
        create_update_campaign_mutation(name: "My Update Campaign", tenant: tenant)
        |> extract_result!()

      assert update_campaign_data["name"] == "My Update Campaign"
      assert update_campaign_data["status"] == "FINISHED"
      assert update_campaign_data["outcome"] == "SUCCESS"
      assert update_campaign_data["updateTargets"] == []
    end

    test "fails when trying to use a non-existing base image", %{tenant: tenant} do
      base_image_id = non_existing_base_image_id(tenant)

      error =
        create_update_campaign_mutation(base_image_id: base_image_id, tenant: tenant)
        |> extract_error!()

      assert %{
               path: ["createUpdateCampaign"],
               fields: [:base_image_id],
               message: "could not be found",
               code: "invalid_attribute"
             } = error
    end

    test "fails when trying to use a non-existing update channel", %{tenant: tenant} do
      update_channel_id = non_existing_update_channel_id(tenant)

      error =
        create_update_campaign_mutation(update_channel_id: update_channel_id, tenant: tenant)
        |> extract_error!()

      assert %{
               path: ["createUpdateCampaign"],
               fields: [:update_channel_id],
               message: "could not be found",
               code: "invalid_attribute"
             } = error
    end

    test "fails when using an invalid rollout mechanism", %{tenant: tenant} do
      rollout_mechanism = %{
        "push" => %{
          "maxFailurePercentage" => -10.0,
          "maxInProgressUpdates" => 5
        }
      }

      error =
        create_update_campaign_mutation(rollout_mechanism: rollout_mechanism, tenant: tenant)
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createUpdateCampaign"],
               fields: [:max_failure_percentage],
               message: "must be more than or equal to 0.0",
               code: "invalid_attribute"
             } = error
    end
  end

  defp create_update_campaign_mutation(opts) do
    default_document = """
    mutation CreateUpdateCampaign($input: CreateUpdateCampaignInput!) {
      createUpdateCampaign(input: $input) {
        result {
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
            id
            version
            url
          }
          updateChannel {
            id
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

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {name, opts} = Keyword.pop_lazy(opts, :name, fn -> unique_update_campaign_name() end)

    {update_channel_id, opts} =
      Keyword.pop_lazy(opts, :update_channel_id, fn ->
        update_channel_fixture(tenant: tenant)
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {base_image_id, opts} =
      Keyword.pop_lazy(opts, :base_image_id, fn ->
        base_image_fixture(tenant: tenant)
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {rollout_mechanism, opts} =
      Keyword.pop_lazy(opts, :rollout_mechanism, fn ->
        %{
          "push" => %{
            "maxFailurePercentage" => 10.0,
            "maxInProgressUpdates" => 10
          }
        }
      end)

    input = %{
      "name" => name,
      "baseImageId" => base_image_id,
      "updateChannelId" => update_channel_id,
      "rolloutMechanism" => rollout_mechanism
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["createUpdateCampaign"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createUpdateCampaign" => %{
                 "result" => update_campaign
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert update_campaign != nil

    update_campaign
  end

  defp non_existing_update_channel_id(tenant) do
    fixture = update_channel_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture, tenant: tenant)

    id
  end

  defp non_existing_base_image_id(tenant) do
    fixture = base_image_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture, action: :destroy_fixture)

    id
  end
end
