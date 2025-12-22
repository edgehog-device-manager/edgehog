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

defmodule EdgehogWeb.Schema.Mutation.CreateCampaignTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.ExecutorRegistry

  describe "createCampaign mutation" do
    test "creates firmware_upgrade campaign with valid data and at least one target", %{
      tenant: tenant
    } do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)
      base_image = base_image_fixture(tenant: tenant)

      device =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with_base_image()
        |> add_tags(["foobar"])

      base_image_id = AshGraphql.Resource.encode_relay_id(base_image)
      channel_id = AshGraphql.Resource.encode_relay_id(channel)

      campaign_data =
        [
          name: "My Firmware Upgrade Campaign",
          base_image_id: base_image_id,
          channel_id: channel_id,
          tenant: tenant
        ]
        |> create_campaign_mutation()
        |> extract_result!()

      assert campaign_data["name"] == "My Firmware Upgrade Campaign"
      assert campaign_data["status"] == "IDLE"
      assert campaign_data["outcome"] == nil
      assert campaign_data["campaignMechanism"]["baseImage"]["id"] == base_image_id

      assert campaign_data["campaignMechanism"]["baseImage"]["version"] ==
               base_image.version

      assert campaign_data["campaignMechanism"]["baseImage"]["url"] == base_image.url
      assert campaign_data["channel"]["id"] == channel_id
      assert campaign_data["channel"]["name"] == channel.name
      assert campaign_data["channel"]["handle"] == channel.handle
      assert [target_data] = extract_nodes!(campaign_data["campaignTargets"]["edges"])
      assert target_data["status"] == "IDLE"
      assert target_data["device"]["id"] == AshGraphql.Resource.encode_relay_id(device)

      # Check that the executor got started
      assert_campaign_executor_started(tenant, campaign_data, :firmware_upgrade)
    end

    test "creates deployment_deploy campaign with valid data and at least one target", %{
      tenant: tenant
    } do
      release = release_fixture(tenant: tenant, system_models: 1)
      target_group = device_group_fixture(selector: ~s<"deploy" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)

      device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["deploy"])

      release_id = AshGraphql.Resource.encode_relay_id(release)
      channel_id = AshGraphql.Resource.encode_relay_id(channel)

      campaign_mechanism = build_deployment_mechanism(:deployment_deploy, release_id)

      campaign_data =
        [
          name: "My Deployment Deploy Campaign",
          campaign_mechanism: campaign_mechanism,
          channel_id: channel_id,
          tenant: tenant
        ]
        |> create_campaign_mutation()
        |> extract_result!()

      assert campaign_data["name"] == "My Deployment Deploy Campaign"
      assert campaign_data["status"] == "IDLE"
      assert campaign_data["outcome"] == nil
      assert campaign_data["campaignMechanism"]["release"]["id"] == release_id
      assert campaign_data["channel"]["id"] == channel_id
      assert [target_data] = extract_nodes!(campaign_data["campaignTargets"]["edges"])
      assert target_data["status"] == "IDLE"
      assert target_data["device"]["id"] == AshGraphql.Resource.encode_relay_id(device)

      # Check that the executor got started
      assert_campaign_executor_started(tenant, campaign_data, :deployment_deploy)
    end

    test "creates deployment_start campaign with valid data", %{tenant: tenant} do
      release = release_fixture(tenant: tenant, system_models: 1)
      target_group = device_group_fixture(selector: ~s<"start" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)

      device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["start"])

      # Create an initial deployment that can be started
      _deployment =
        deployment_fixture(device_id: device.id, release_id: release.id, tenant: tenant)

      release_id = AshGraphql.Resource.encode_relay_id(release)
      channel_id = AshGraphql.Resource.encode_relay_id(channel)

      campaign_mechanism = build_deployment_mechanism(:deployment_start, release_id)

      campaign_data =
        [
          name: "My Deployment Start Campaign",
          campaign_mechanism: campaign_mechanism,
          channel_id: channel_id,
          tenant: tenant
        ]
        |> create_campaign_mutation()
        |> extract_result!()

      assert campaign_data["name"] == "My Deployment Start Campaign"
      assert campaign_data["status"] == "IDLE"
      assert campaign_data["campaignMechanism"]["release"]["id"] == release_id

      # Check that the executor got started
      assert_campaign_executor_started(tenant, campaign_data, :deployment_start)
    end

    test "creates deployment_stop campaign with valid data", %{tenant: tenant} do
      release = release_fixture(tenant: tenant, system_models: 1)
      target_group = device_group_fixture(selector: ~s<"stop" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)

      device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["stop"])

      # Create an initial deployment that can be stopped
      _deployment =
        deployment_fixture(device_id: device.id, release_id: release.id, tenant: tenant)

      release_id = AshGraphql.Resource.encode_relay_id(release)
      channel_id = AshGraphql.Resource.encode_relay_id(channel)

      campaign_mechanism = build_deployment_mechanism(:deployment_stop, release_id)

      campaign_data =
        [
          name: "My Deployment Stop Campaign",
          campaign_mechanism: campaign_mechanism,
          channel_id: channel_id,
          tenant: tenant
        ]
        |> create_campaign_mutation()
        |> extract_result!()

      assert campaign_data["name"] == "My Deployment Stop Campaign"
      assert campaign_data["status"] == "IDLE"
      assert campaign_data["campaignMechanism"]["release"]["id"] == release_id

      # Check that the executor got started
      assert_campaign_executor_started(tenant, campaign_data, :deployment_stop)
    end

    test "creates deployment_delete campaign with valid data", %{tenant: tenant} do
      release = release_fixture(tenant: tenant, system_models: 1)
      target_group = device_group_fixture(selector: ~s<"delete" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)

      device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["delete"])

      # Create an initial deployment that can be deleted
      _deployment =
        deployment_fixture(device_id: device.id, release_id: release.id, tenant: tenant)

      release_id = AshGraphql.Resource.encode_relay_id(release)
      channel_id = AshGraphql.Resource.encode_relay_id(channel)

      campaign_mechanism = build_deployment_mechanism(:deployment_delete, release_id)

      campaign_data =
        [
          name: "My Deployment Delete Campaign",
          campaign_mechanism: campaign_mechanism,
          channel_id: channel_id,
          tenant: tenant
        ]
        |> create_campaign_mutation()
        |> extract_result!()

      assert campaign_data["name"] == "My Deployment Delete Campaign"
      assert campaign_data["status"] == "IDLE"
      assert campaign_data["campaignMechanism"]["release"]["id"] == release_id

      # Check that the executor got started
      assert_campaign_executor_started(tenant, campaign_data, :deployment_delete)
    end

    test "creates deployment_upgrade campaign with valid data", %{tenant: tenant} do
      # Create releases in the same application
      release = release_fixture(tenant: tenant, version: "1.0.0", system_models: 1)
      application_id = Ash.load!(release, :application, tenant: tenant).application.id

      target_release =
        release_fixture(
          tenant: tenant,
          version: "1.0.1",
          system_models: 1,
          application_id: application_id
        )

      target_group = device_group_fixture(selector: ~s<"upgrade" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)

      device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["upgrade"])

      # Create an initial deployment that can be upgraded
      _deployment =
        deployment_fixture(device_id: device.id, release_id: release.id, tenant: tenant)

      release_id = AshGraphql.Resource.encode_relay_id(release)
      target_release_id = AshGraphql.Resource.encode_relay_id(target_release)
      channel_id = AshGraphql.Resource.encode_relay_id(channel)

      campaign_mechanism =
        build_deployment_mechanism(:deployment_upgrade, release_id, target_release_id: target_release_id)

      campaign_data =
        [
          name: "My Deployment Upgrade Campaign",
          campaign_mechanism: campaign_mechanism,
          channel_id: channel_id,
          tenant: tenant
        ]
        |> create_campaign_mutation()
        |> extract_result!()

      assert campaign_data["name"] == "My Deployment Upgrade Campaign"
      assert campaign_data["status"] == "IDLE"
      assert campaign_data["campaignMechanism"]["release"]["id"] == release_id
      assert campaign_data["campaignMechanism"]["targetRelease"]["id"] == target_release_id

      # Check that the executor got started
      assert_campaign_executor_started(tenant, campaign_data, :deployment_upgrade)
    end

    test "creates finished update_campaign with valid data and no targets", %{tenant: tenant} do
      campaign_data =
        [name: "My Update Campaign", tenant: tenant]
        |> create_campaign_mutation()
        |> extract_result!()

      assert campaign_data["name"] == "My Update Campaign"
      assert campaign_data["status"] == "FINISHED"
      assert campaign_data["outcome"] == "SUCCESS"
      assert campaign_data["campaignTargets"]["edges"] == []

      # Check that no executor got started
      assert_campaign_executor_not_started(tenant, campaign_data, :firmware_upgrade)
    end

    test "creates update campaign with default values for campaign mechanism", %{tenant: tenant} do
      campaign_mechanism = %{
        "firmware_upgrade" => %{
          "maxFailurePercentage" => 0.0,
          "maxInProgressOperations" => 1
        }
      }

      campaign_data =
        [campaign_mechanism: campaign_mechanism, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_result!()

      assert campaign_mechanism_data = campaign_data["campaignMechanism"]
      assert campaign_mechanism_data["requestRetries"] == 3
      assert campaign_mechanism_data["requestTimeoutSeconds"] == 300
      assert campaign_mechanism_data["forceDowngrade"] == false
    end

    test "creates update campaign with specified values for rollout mechanism", %{tenant: tenant} do
      campaign_mechanism = %{
        "firmware_upgrade" => %{
          "maxFailurePercentage" => 5.0,
          "maxInProgressOperations" => 5,
          "requestRetries" => 10,
          "requestTimeoutSeconds" => 120,
          "forceDowngrade" => true
        }
      }

      campaign_data =
        [campaign_mechanism: campaign_mechanism, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_result!()

      assert campaign_mechanism_data = campaign_data["campaignMechanism"]
      assert campaign_mechanism_data["maxFailurePercentage"] == 5.0
      assert campaign_mechanism_data["maxInProgressOperations"] == 5
      assert campaign_mechanism_data["requestRetries"] == 10
      assert campaign_mechanism_data["requestTimeoutSeconds"] == 120
      assert campaign_mechanism_data["forceDowngrade"] == true
    end

    test "fails when trying to use a non-existing base image", %{tenant: tenant} do
      base_image_id = non_existing_base_image_id(tenant)

      error =
        [base_image_id: base_image_id, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{
               path: ["createCampaign"],
               fields: [:base_image_id],
               message: "could not be found",
               code: "invalid_attribute"
             } = error
    end

    test "fails when trying to use a non-existing channel", %{tenant: tenant} do
      channel_id = non_existing_channel_id(tenant)

      error =
        [channel_id: channel_id, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{
               path: ["createCampaign"],
               fields: [:channel_id],
               message: "could not be found",
               code: "invalid_attribute"
             } = error
    end

    test "fails with missing name", %{tenant: tenant} do
      error =
        [name: nil, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{message: message} = error
      assert message =~ ~s<In field "name": Expected type "String!", found null.>
    end

    test "fails with empty name", %{tenant: tenant} do
      error =
        [name: "", tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{
               path: ["createCampaign"],
               fields: [:name],
               message: "is required",
               code: "required"
             } = error
    end

    test "fails with missing campaign mechanism", %{tenant: tenant} do
      error =
        [campaign_mechanism: nil, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{message: message} = error

      assert message =~
               ~s<In field "campaignMechanism": Expected type "CampaignMechanismInput!", found null.>
    end

    test "fails with empty campaign mechanism", %{tenant: tenant} do
      error =
        [campaign_mechanism: %{}, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{
               path: ["createCampaign"],
               fields: [:campaign_mechanism],
               message: "Campaign mechanism cannot be an empty map",
               code: "invalid_attribute"
             } = error
    end

    test "fails when using an invalid max_failure_percentage", %{tenant: tenant} do
      campaign_mechanism = %{
        "firmware_upgrade" => %{
          "maxFailurePercentage" => -10.0,
          "maxInProgressOperations" => 1
        }
      }

      error =
        [campaign_mechanism: campaign_mechanism, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createCampaign"],
               fields: [:max_failure_percentage],
               message: "must be more than or equal to 0.0",
               code: "invalid_attribute"
             } = error

      campaign_mechanism = %{
        "firmware_upgrade" => %{
          "maxFailurePercentage" => 110.0,
          "maxInProgressOperations" => 1
        }
      }

      error =
        [campaign_mechanism: campaign_mechanism, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createCampaign"],
               fields: [:max_failure_percentage],
               message: "must be less than or equal to 100.0",
               code: "invalid_attribute"
             } = error
    end

    test "fails when using an invalid max_in_progress_operations", %{tenant: tenant} do
      campaign_mechanism = %{
        "firmware_upgrade" => %{
          "maxInProgressOperations" => -1,
          "maxFailurePercentage" => 0.0
        }
      }

      error =
        [campaign_mechanism: campaign_mechanism, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createCampaign"],
               fields: [:max_in_progress_operations],
               message: "must be more than or equal to 1",
               code: "invalid_attribute"
             } = error
    end

    test "fails when using an invalid request_retries", %{tenant: tenant} do
      campaign_mechanism = %{
        "firmware_upgrade" => %{
          "requestRetries" => -1,
          "maxFailurePercentage" => 0.0,
          "maxInProgressOperations" => 1
        }
      }

      error =
        [campaign_mechanism: campaign_mechanism, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createCampaign"],
               fields: [:request_retries],
               message: "must be more than or equal to 0",
               code: "invalid_attribute"
             } = error
    end

    test "fails when using an invalid request_timeout_seconds", %{tenant: tenant} do
      campaign_mechanism = %{
        "firmware_upgrade" => %{
          "requestTimeoutSeconds" => -1,
          "maxFailurePercentage" => 0.0,
          "maxInProgressOperations" => 1
        }
      }

      error =
        [campaign_mechanism: campaign_mechanism, tenant: tenant]
        |> create_campaign_mutation()
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createCampaign"],
               fields: [:request_timeout_seconds],
               message: "must be more than or equal to 30",
               code: "invalid_attribute"
             } = error
    end
  end

  defp create_campaign_mutation(opts) do
    default_document = """
      mutation CreateCampaign($input: CreateCampaignInput!) {
      createCampaign(input: $input) {
        result {
          id
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
            ... on DeploymentStart {
              maxFailurePercentage
              maxInProgressOperations
              requestRetries
              requestTimeoutSeconds
              release {
                id
              }
            }
            ... on DeploymentStop {
              maxFailurePercentage
              maxInProgressOperations
              requestRetries
              requestTimeoutSeconds
              release {
                id
              }
            }
            ... on DeploymentDelete {
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
          channel {
            id
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
    }

    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {name, opts} = Keyword.pop_lazy(opts, :name, fn -> unique_campaign_name() end)

    {channel_id, opts} =
      Keyword.pop_lazy(opts, :channel_id, fn ->
        [tenant: tenant]
        |> channel_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    # Check if campaign_mechanism was explicitly passed (even if nil)
    explicit_mechanism = Keyword.has_key?(opts, :campaign_mechanism)
    {campaign_mechanism, opts} = Keyword.pop(opts, :campaign_mechanism)

    # Get base_image_id if provided
    {base_image_id, opts} = Keyword.pop(opts, :base_image_id)

    # Determine mechanism type and create necessary resources
    # Explicitly provided (including nil or %{}) - use as-is for testing
    campaign_mechanism =
      if explicit_mechanism do
        campaign_mechanism
      else
        # No mechanism provided - create default firmware_upgrade
        # Use provided base_image_id or create one
        base_image_id =
          base_image_id ||
            [tenant: tenant]
            |> base_image_fixture()
            |> AshGraphql.Resource.encode_relay_id()

        %{
          "firmware_upgrade" => %{
            "maxFailurePercentage" => 10.0,
            "maxInProgressOperations" => 10,
            "baseImageId" => base_image_id
          }
        }
      end

    # If mechanism has firmware_upgrade without baseImageId, inject it
    campaign_mechanism =
      if is_map(campaign_mechanism) &&
           Map.has_key?(campaign_mechanism, "firmware_upgrade") &&
           !Map.has_key?(campaign_mechanism["firmware_upgrade"], "baseImageId") do
        # Use provided base_image_id or create one
        base_image_id =
          base_image_id ||
            [tenant: tenant]
            |> base_image_fixture()
            |> AshGraphql.Resource.encode_relay_id()

        update_in(
          campaign_mechanism["firmware_upgrade"],
          &Map.put(&1, "baseImageId", base_image_id)
        )
      else
        campaign_mechanism
      end

    input = %{
      "name" => name,
      "channelId" => channel_id,
      "campaignMechanism" => campaign_mechanism
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["createCampaign"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createCampaign" => %{
                 "result" => campaign
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert campaign

    campaign
  end

  defp build_deployment_mechanism(type, release_id, opts \\ []) do
    target_release_id = Keyword.get(opts, :target_release_id)

    mechanism = %{
      "releaseId" => release_id,
      "maxFailurePercentage" => 10.0,
      "maxInProgressOperations" => 10
    }

    mechanism =
      if target_release_id do
        Map.put(mechanism, "targetReleaseId", target_release_id)
      else
        mechanism
      end

    %{Atom.to_string(type) => mechanism}
  end

  defp non_existing_channel_id(tenant) do
    fixture = channel_fixture(tenant: tenant)
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

  defp fetch_campaign_from_graphql_id!(tenant, id) do
    assert {:ok, %{type: :campaign, id: decoded_id}} =
             AshGraphql.Resource.decode_relay_id(id)

    Ash.get!(Campaign, decoded_id, tenant: tenant)
  end

  defp fetch_campaign_executor_pid(tenant, campaign, mechanism_type) do
    key = {tenant.tenant_id, campaign.id, mechanism_type}

    case Registry.lookup(ExecutorRegistry, key) do
      [] -> :error
      [{pid, _}] -> {:ok, pid}
    end
  end

  defp assert_campaign_executor_started(tenant, campaign_data, mechanism_type) do
    campaign = fetch_campaign_from_graphql_id!(tenant, campaign_data["id"])
    assert {:ok, pid} = fetch_campaign_executor_pid(tenant, campaign, mechanism_type)
    assert {:wait_for_start_execution, _data} = :sys.get_state(pid)
  end

  defp assert_campaign_executor_not_started(tenant, campaign_data, mechanism_type) do
    campaign = fetch_campaign_from_graphql_id!(tenant, campaign_data["id"])
    assert :error = fetch_campaign_executor_pid(tenant, campaign, mechanism_type)
  end

  defp extract_nodes!(data) do
    Enum.map(data, &Map.fetch!(&1, "node"))
  end
end
