#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.CreateDeploymentCampaignTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DeploymentCampaignsFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  alias Edgehog.Campaigns.ExecutorRegistry
  alias Edgehog.DeploymentCampaigns.DeploymentCampaign

  describe "createDeploymentCampaign mutation" do
    test "creates a deployment campaign with valid data and at least one target", %{
      tenant: tenant
    } do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)
      release = release_fixture(system_models: 1, tenant: tenant)

      device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      release_id = AshGraphql.Resource.encode_relay_id(release)
      channel_id = AshGraphql.Resource.encode_relay_id(channel)

      campaign_name = "Test deployment campaign"

      deployment_campaign_data =
        [
          name: campaign_name,
          release_id: release_id,
          channel_id: channel_id,
          tenant: tenant
        ]
        |> create_deployment_campaign_mutation()
        |> extract_result!()

      assert ^campaign_name = deployment_campaign_data["name"]
      assert "IDLE" = deployment_campaign_data["status"]
      assert deployment_campaign_data["outcome"] == nil
      assert deployment_campaign_data["release"]["id"] == release_id
      assert deployment_campaign_data["release"]["version"] == release.version
      assert deployment_campaign_data["channel"]["id"] == channel_id
      assert deployment_campaign_data["channel"]["name"] == channel.name
      assert deployment_campaign_data["channel"]["handle"] == channel.handle

      assert [target_data] =
               extract_nodes!(deployment_campaign_data["deploymentTargets"]["edges"])

      assert "IDLE" = target_data["status"]

      expected_device_id = AshGraphql.Resource.encode_relay_id(device)
      assert target_data["device"]["id"] == expected_device_id

      # Check that the executor got started
      deployment_campaign =
        fetch_deployment_campaign_from_graphql_id!(tenant, deployment_campaign_data["id"])

      assert {:ok, pid} = fetch_deployment_campaign_executor_pid(tenant, deployment_campaign)
      assert {:wait_for_start_execution, _data} = :sys.get_state(pid)
    end

    test "creates finished deployment_campaign with valid data and no targets", %{tenant: tenant} do
      campaign_name = "Test Deployment Campaign"

      deployment_campaign_data =
        [name: campaign_name, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_result!()

      assert ^campaign_name = deployment_campaign_data["name"]
      assert "FINISHED" = deployment_campaign_data["status"]
      assert "SUCCESS" = deployment_campaign_data["outcome"]
      assert [] = deployment_campaign_data["deploymentTargets"]["edges"]

      # Check that no executor got started
      deployment_campaign =
        fetch_deployment_campaign_from_graphql_id!(tenant, deployment_campaign_data["id"])

      assert :error = fetch_deployment_campaign_executor_pid(tenant, deployment_campaign)
    end

    test "fails when trying to use a non-existing release", %{tenant: tenant} do
      release_id = non_existing_release_id(tenant)

      error =
        [release_id: release_id, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               path: ["createDeploymentCampaign"],
               fields: [:release_id],
               message: "could not be found",
               code: "invalid_attribute"
             } = error
    end

    test "fails when trying to use a non-existing deployment channel", %{tenant: tenant} do
      channel_id = non_existing_channel_id(tenant)

      error =
        [channel_id: channel_id, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               path: ["createDeploymentCampaign"],
               fields: [:channel_id],
               message: "could not be found",
               code: "invalid_attribute"
             } = error
    end

    test "fails with missing name", %{tenant: tenant} do
      error =
        [name: nil, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{message: message} = error
      assert message =~ ~s<In field "name": Expected type "String!", found null.>
    end

    test "fails with empty name", %{tenant: tenant} do
      error =
        [name: "", tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               path: ["createDeploymentCampaign"],
               fields: [:name],
               message: "is required",
               code: "required"
             } = error
    end

    test "fails with missing rollout mechanism", %{tenant: tenant} do
      error =
        [deployment_mechanism: nil, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{message: message} = error

      assert message =~
               ~s<In field "deploymentMechanism": Expected type "DeploymentMechanismInput!", found null.>
    end

    test "fails with empty rollout mechanism", %{tenant: tenant} do
      error =
        [deployment_mechanism: %{}, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               path: ["createDeploymentCampaign"],
               fields: [:deployment_mechanism],
               message: "is required",
               code: "required"
             } = error
    end

    test "fails when using an invalid max_failure_percentage", %{tenant: tenant} do
      deployment_mechanism = %{
        "lazy" => %{
          "maxFailurePercentage" => -10.0,
          "maxInProgressDeployments" => 1
        }
      }

      error =
        [deployment_mechanism: deployment_mechanism, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createDeploymentCampaign"],
               fields: [:max_failure_percentage],
               message: "must be more than or equal to 0.0",
               code: "invalid_attribute"
             } = error

      deployment_mechanism = %{
        "lazy" => %{
          "maxFailurePercentage" => 110.0,
          "maxInProgressDeployments" => 1
        }
      }

      error =
        [deployment_mechanism: deployment_mechanism, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createDeploymentCampaign"],
               fields: [:max_failure_percentage],
               message: "must be less than or equal to 100.0",
               code: "invalid_attribute"
             } = error
    end

    test "fails when using an invalid max_in_progress_deployments", %{tenant: tenant} do
      deployment_mechanism = %{
        "lazy" => %{
          "maxInProgressDeployments" => -1,
          "maxFailurePercentage" => 0.0
        }
      }

      error =
        [deployment_mechanism: deployment_mechanism, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createDeploymentCampaign"],
               fields: [:max_in_progress_deployments],
               message: "must be more than or equal to 1",
               code: "invalid_attribute"
             } = error
    end

    test "fails when using an invalid ota_request_retries", %{tenant: tenant} do
      deployment_mechanism = %{
        "lazy" => %{
          "createRequestRetries" => -1,
          "maxFailurePercentage" => 0.0,
          "maxInProgressDeployments" => 1
        }
      }

      error =
        [deployment_mechanism: deployment_mechanism, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createDeploymentCampaign"],
               fields: [:create_request_retries],
               message: "must be more than or equal to 0",
               code: "invalid_attribute"
             } = error
    end

    test "fails when using an invalid ota_request_timeout_seconds", %{tenant: tenant} do
      deployment_mechanism = %{
        "lazy" => %{
          "requestTimeoutSeconds" => -1,
          "maxFailurePercentage" => 0.0,
          "maxInProgressDeployments" => 1
        }
      }

      error =
        [deployment_mechanism: deployment_mechanism, tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               # TODO: Ash doesn't report the full nested path
               path: ["createDeploymentCampaign"],
               fields: [:request_timeout_seconds],
               message: "must be more than or equal to 30",
               code: "invalid_attribute"
             } = error
    end

    test "creates deployment campaign with upgrade operation type and target release", %{
      tenant: tenant
    } do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)
      application = application_fixture(tenant: tenant)

      release =
        release_fixture(
          application_id: application.id,
          version: "1.0.0",
          system_models: 1,
          tenant: tenant
        )

      target_release =
        release_fixture(
          application_id: application.id,
          version: "1.1.0",
          system_models: 1,
          tenant: tenant
        )

      device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      # Deploy the source release to the device so it can be upgraded
      _deployment =
        deployment_fixture(
          device_id: device.id,
          release_id: release.id,
          tenant: tenant
        )

      release_id = AshGraphql.Resource.encode_relay_id(release)
      target_release_id = AshGraphql.Resource.encode_relay_id(target_release)
      channel_id = AshGraphql.Resource.encode_relay_id(channel)

      campaign_name = "Test upgrade campaign"

      deployment_campaign_data =
        [
          name: campaign_name,
          release_id: release_id,
          target_release_id: target_release_id,
          channel_id: channel_id,
          operation_type: "UPGRADE",
          tenant: tenant
        ]
        |> create_deployment_campaign_mutation()
        |> extract_result!()

      assert ^campaign_name = deployment_campaign_data["name"]
      assert "IDLE" = deployment_campaign_data["status"]
      assert deployment_campaign_data["operationType"] == "UPGRADE"
      assert deployment_campaign_data["release"]["id"] == release_id
      assert deployment_campaign_data["targetRelease"]["id"] == target_release_id
    end

    test "fails when upgrade operation type is used with smaller target release", %{
      tenant: tenant
    } do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)
      application = application_fixture(tenant: tenant)

      release =
        release_fixture(
          application_id: application.id,
          version: "2.0.0",
          system_models: 1,
          tenant: tenant
        )

      target_release =
        release_fixture(
          application_id: application.id,
          version: "1.1.0",
          system_models: 1,
          tenant: tenant
        )

      _device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      release_id = AshGraphql.Resource.encode_relay_id(release)
      target_release_id = AshGraphql.Resource.encode_relay_id(target_release)
      channel_id = AshGraphql.Resource.encode_relay_id(channel)

      campaign_name = "Test upgrade campaign"

      error =
        [
          name: campaign_name,
          release_id: release_id,
          target_release_id: target_release_id,
          channel_id: channel_id,
          operation_type: "UPGRADE",
          tenant: tenant
        ]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               path: ["createDeploymentCampaign"],
               fields: [:target_release_id],
               message: "must be a newer release than the currently installed version",
               code: "invalid_attribute"
             } = error
    end

    test "fails when upgrade operation type is used without target_release_id", %{tenant: tenant} do
      error =
        [operation_type: "UPGRADE", tenant: tenant]
        |> create_deployment_campaign_mutation()
        |> extract_error!()

      assert %{
               path: ["createDeploymentCampaign"],
               fields: [:target_release_id],
               message: "is required for upgrade operations",
               code: "invalid_attribute"
             } = error
    end
  end

  defp create_deployment_campaign_mutation(opts) do
    default_document = """
    mutation CreateDeploymentCampaign($input: CreateDeploymentCampaignInput!) {
      createDeploymentCampaign(input: $input) {
        result {
          id
          name
          status
          outcome
          operationType
          deploymentMechanism {
            ... on Lazy {
              maxFailurePercentage
              maxInProgressDeployments
              createRequestRetries
              requestTimeoutSeconds
            }
          }
          release {
            id
            version
          }
          targetRelease {
            id
            version
          }
          channel {
            id
            name
            handle
          }
          deploymentTargets {
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

    {name, opts} = Keyword.pop_lazy(opts, :name, fn -> unique_deployment_campaign_name() end)

    {channel_id, opts} =
      Keyword.pop_lazy(opts, :channel_id, fn ->
        [tenant: tenant]
        |> channel_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {release_id, opts} =
      Keyword.pop_lazy(opts, :release_id, fn ->
        [tenant: tenant]
        |> release_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {target_release_id, opts} = Keyword.pop(opts, :target_release_id)

    {operation_type, opts} = Keyword.pop(opts, :operation_type)

    {deployment_mechanism, opts} =
      Keyword.pop_lazy(opts, :deployment_mechanism, fn ->
        %{
          "lazy" => %{
            "maxFailurePercentage" => 10.0,
            "maxInProgressDeployments" => 10
          }
        }
      end)

    input =
      %{
        "name" => name,
        "releaseId" => release_id,
        "channelId" => channel_id,
        "deploymentMechanism" => deployment_mechanism
      }
      |> maybe_add_field("targetReleaseId", target_release_id)
      |> maybe_add_field("operationType", operation_type)

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp maybe_add_field(map, _key, nil), do: map
  defp maybe_add_field(map, key, value), do: Map.put(map, key, value)

  defp extract_error!(result) do
    assert is_nil(result[:data]["createDeploymentCampaign"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createDeploymentCampaign" => %{
                 "result" => deployment_campaign
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert deployment_campaign != nil

    deployment_campaign
  end

  defp fetch_deployment_campaign_from_graphql_id!(tenant, id) do
    assert {:ok, %{type: :deployment_campaign, id: decoded_id}} =
             AshGraphql.Resource.decode_relay_id(id)

    Ash.get!(DeploymentCampaign, decoded_id, tenant: tenant)
  end

  defp fetch_deployment_campaign_executor_pid(tenant, deployment_campaign) do
    key = {tenant.tenant_id, deployment_campaign.id, :deployment}

    case Registry.lookup(ExecutorRegistry, key) do
      [] -> :error
      [{pid, _}] -> {:ok, pid}
    end
  end

  defp extract_nodes!(data) do
    Enum.map(data, &Map.fetch!(&1, "node"))
  end

  defp non_existing_release_id(tenant) do
    fixture = release_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture)

    id
  end

  defp non_existing_channel_id(tenant) do
    fixture = channel_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture, tenant: tenant)

    id
  end
end
