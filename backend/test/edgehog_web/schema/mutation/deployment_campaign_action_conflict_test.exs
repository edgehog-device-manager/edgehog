#
# This file is part of Edgehog.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.DeploymentCampaignActionConflictTest do
  @moduledoc """
  Tests for validating that deployment actions are blocked when the deployment
  is part of an in-progress campaign with a different operation type.
  """
  use EdgehogWeb.GraphqlCase, async: true

  import Ash.Expr
  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  alias Edgehog.Astarte.Device.DeploymentCommandMock

  require Ash.Query

  setup %{tenant: tenant} do
    # Create a deployment that is in a ready state
    {:ok, deployment} =
      [tenant: tenant]
      |> deployment_fixture()
      |> Edgehog.Containers.mark_deployment_as_stopped(tenant: tenant)

    %{deployment: deployment}
  end

  describe "deployment action validation with in-progress campaigns" do
    test "start action succeeds for stopped deployment with upgrade campaign (retry logic)", %{
      tenant: tenant,
      deployment: deployment
    } do
      # Load deployment with release to get the application
      deployment = Ash.load!(deployment, [release: :application], tenant: tenant)
      application_id = deployment.release.application_id

      # Create target release for the same application
      target_release =
        release_fixture(
          tenant: tenant,
          application_id: application_id,
          version: "2.0.0"
        )

      # Create a campaign with upgrade operation type and target_release_id
      _campaign =
        create_in_progress_campaign(tenant, :deployment_upgrade, deployment, target_release_id: target_release.id)

      expect(DeploymentCommandMock, :send_deployment_command, 1, fn _, _, _ -> :ok end)

      result = send_start_deployment_mutation(tenant: tenant, deployment: deployment)

      assert %{
               data: %{
                 "startDeployment" => %{
                   "result" => %{"id" => _}
                 }
               }
             } = result
    end

    test "start action succeeds when deployment has no associated campaign", %{
      tenant: tenant,
      deployment: deployment
    } do
      expect(DeploymentCommandMock, :send_deployment_command, 1, fn _, _, _ -> :ok end)

      result = send_start_deployment_mutation(tenant: tenant, deployment: deployment)

      assert %{
               data: %{
                 "startDeployment" => %{
                   "result" => %{"id" => _}
                 }
               }
             } = result
    end

    test "start action fails when deployment is part of in-progress stop campaign", %{
      tenant: tenant,
      deployment: deployment
    } do
      # Create a campaign with stop operation type
      _campaign = create_in_progress_campaign(tenant, :deployment_stop, deployment)

      result = send_start_deployment_mutation(tenant: tenant, deployment: deployment)

      assert %{
               data: %{"startDeployment" => nil},
               errors: [%{message: message}]
             } = result

      assert message =~ "This deployment is locked due to an ongoing deployment_stop campaign"
    end

    test "start action succeeds when campaign with start operation is in progress", %{
      tenant: tenant,
      deployment: deployment
    } do
      # Create a campaign with the same operation type (start)
      _campaign = create_in_progress_campaign(tenant, :deployment_start, deployment)

      expect(DeploymentCommandMock, :send_deployment_command, 1, fn _, _, _ -> :ok end)

      result = send_start_deployment_mutation(tenant: tenant, deployment: deployment)

      assert %{
               data: %{
                 "startDeployment" => %{
                   "result" => %{"id" => _}
                 }
               }
             } = result
    end

    test "start action succeeds when campaign is not in progress", %{
      tenant: tenant,
      deployment: deployment
    } do
      # Create a campaign that is idle (not in progress)
      _campaign = create_idle_campaign(tenant, :deployment_stop, deployment)

      expect(DeploymentCommandMock, :send_deployment_command, 1, fn _, _, _ -> :ok end)

      result = send_start_deployment_mutation(tenant: tenant, deployment: deployment)

      assert %{
               data: %{
                 "startDeployment" => %{
                   "result" => %{"id" => _}
                 }
               }
             } = result
    end

    test "stop action fails when deployment is part of in-progress deployment_delete campaign", %{
      tenant: tenant,
      deployment: deployment
    } do
      # Mark deployment as started so stop action can work
      {:ok, deployment} =
        Edgehog.Containers.mark_deployment_as_started(deployment, tenant: tenant)

      # Create a campaign with delete operation type
      _campaign = create_in_progress_campaign(tenant, :deployment_delete, deployment)

      result = send_stop_deployment_mutation(tenant: tenant, deployment: deployment)

      assert %{
               data: %{"stopDeployment" => nil},
               errors: [%{message: message}]
             } = result

      assert message =~ "This deployment is locked due to an ongoing deployment_delete campaign"
    end

    test "delete action fails when deployment is part of in-progress deployment_start campaign",
         %{
           tenant: tenant,
           deployment: deployment
         } do
      # Create a campaign with start operation type
      _campaign = create_in_progress_campaign(tenant, :deployment_start, deployment)

      result = send_delete_deployment_mutation(tenant: tenant, deployment: deployment)

      assert %{
               data: %{"deleteDeployment" => nil},
               errors: [%{message: message}]
             } = result

      assert message =~ "This deployment is locked due to an ongoing deployment_start campaign"
    end

    test "upgrade action fails when deployment is part of in-progress deployment_stop campaign",
         %{
           tenant: tenant,
           deployment: deployment
         } do
      # Load deployment with release to get the application
      deployment = Ash.load!(deployment, [release: :application], tenant: tenant)
      application_id = deployment.release.application_id

      # Create target release for the same application
      target_release =
        release_fixture(
          tenant: tenant,
          application_id: application_id,
          version: "2.0.0"
        )

      # Create a campaign with stop operation type
      _campaign = create_in_progress_campaign(tenant, :deployment_stop, deployment)

      result =
        send_upgrade_deployment_mutation(
          tenant: tenant,
          deployment: deployment,
          target_release: target_release
        )

      assert %{
               data: %{"upgradeDeployment" => nil},
               errors: [%{message: message}]
             } = result

      assert message =~ "This deployment is locked due to an ongoing deployment_stop campaign"
    end

    test "all actions succeed when campaign is finished", %{
      tenant: tenant,
      deployment: deployment
    } do
      # Create a campaign that is finished
      _campaign = create_finished_campaign(tenant, :deployment_stop, deployment)

      expect(DeploymentCommandMock, :send_deployment_command, 1, fn _, _, _ -> :ok end)

      result = send_start_deployment_mutation(tenant: tenant, deployment: deployment)

      assert %{
               data: %{
                 "startDeployment" => %{
                   "result" => %{"id" => _}
                 }
               }
             } = result
    end
  end

  # Helper functions to create campaigns

  defp create_in_progress_campaign(tenant, operation_type, deployment, opts \\ []) do
    campaign = create_campaign_for_deployment(tenant, operation_type, deployment, opts)

    # Mark campaign as in progress
    campaign
    |> Ash.Changeset.for_update(:mark_as_in_progress, %{}, tenant: tenant)
    |> Ash.update!()
  end

  defp create_idle_campaign(tenant, operation_type, deployment) do
    create_campaign_for_deployment(tenant, operation_type, deployment)
  end

  defp create_finished_campaign(tenant, operation_type, deployment) do
    campaign = create_campaign_for_deployment(tenant, operation_type, deployment)

    # Mark campaign as finished
    campaign
    |> Ash.Changeset.for_update(:mark_as_successful, %{}, tenant: tenant)
    |> Ash.update!()
  end

  defp create_campaign_for_deployment(tenant, operation_type, deployment, opts \\ []) do
    # Load the deployment with device and release
    deployment = Ash.load!(deployment, [:device, :release], tenant: tenant)

    # Create a device group that includes the deployment's device
    # Use a unique tag to ensure only this device is in the group
    tag = "test-#{System.unique_integer([:positive])}"

    # Add the tag to the device
    _device = add_tags(deployment.device, [tag])

    # Create a device group with a selector for this tag
    device_group = device_group_fixture(selector: ~s<"#{tag}" in tags>, tenant: tenant)

    # Create a channel targeting this group
    channel = channel_fixture(target_group_ids: [device_group.id], tenant: tenant)

    # Create a campaign for this channel
    campaign =
      campaign_fixture(
        [
          tenant: tenant,
          mechanism_type: operation_type,
          release_id: deployment.release_id,
          channel_id: channel.id
        ] ++ opts
      )

    # Find and link the deployment target to the deployment
    target =
      Edgehog.Campaigns.CampaignTarget
      |> Ash.Query.filter(expr(campaign_id == ^campaign.id and device_id == ^deployment.device_id))
      |> Ash.read_one!(tenant: tenant)

    # Link the deployment to the target
    target
    |> Ash.Changeset.for_update(:set_deployment, %{deployment_id: deployment.id}, tenant: tenant)
    |> Ash.update!()

    campaign
  end

  # Mutation helper functions

  defp send_start_deployment_mutation(opts) do
    document = """
    mutation StartDeployment($id: ID!) {
      startDeployment(id: $id) {
        result {
          id
        }
      }
    }
    """

    send_mutation(document, opts, "id")
  end

  defp send_stop_deployment_mutation(opts) do
    document = """
    mutation StopDeployment($id: ID!) {
      stopDeployment(id: $id) {
        result {
          id
        }
      }
    }
    """

    send_mutation(document, opts, "id")
  end

  defp send_delete_deployment_mutation(opts) do
    document = """
    mutation DeleteDeployment($id: ID!) {
      deleteDeployment(id: $id) {
        result {
          id
        }
      }
    }
    """

    send_mutation(document, opts, "id")
  end

  defp send_upgrade_deployment_mutation(opts) do
    document = """
    mutation UpgradeDeployment($id: ID!, $input: UpgradeDeploymentInput!) {
      upgradeDeployment(id: $id, input: $input) {
        result {
          id
        }
      }
    }
    """

    {target_release, opts} = Keyword.pop!(opts, :target_release)

    variables = %{
      "input" => %{
        "target" => AshGraphql.Resource.encode_relay_id(target_release)
      }
    }

    send_mutation(document, opts, "id", variables)
  end

  defp send_mutation(document, opts, id_key, extra_variables \\ %{}) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {deployment, _opts} = Keyword.pop!(opts, :deployment)

    variables =
      Map.merge(
        %{
          id_key => AshGraphql.Resource.encode_relay_id(deployment)
        },
        extra_variables
      )

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end
end
