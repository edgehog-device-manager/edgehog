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

defmodule Edgehog.Campaigns.CampaignMechanism.DeploymentDeploy.CoreTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures
  import Mox

  alias Edgehog.Astarte.Device.CreateDeploymentRequestMock
  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.CampaignMechanism.Core
  alias Edgehog.Campaigns.CampaignMechanism.DeploymentDeploy
  alias Phoenix.Socket.Broadcast

  setup :verify_on_exit!

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "get_operation_id/2" do
    test "returns nil when target has no deployment", %{tenant: tenant} do
      target = target_fixture(tenant: tenant, mechanism_type: :deployment_deploy)

      mechanism = %DeploymentDeploy{}

      assert Core.get_operation_id(mechanism, target) == nil
    end

    test "returns deployment_id when target has deployment", %{tenant: tenant} do
      deployment = deployment_fixture(tenant: tenant)

      target =
        [tenant: tenant, mechanism_type: :deployment_deploy]
        |> target_fixture()
        |> Campaigns.set_target_deployment(deployment.id, tenant: tenant.tenant_id)
        |> Ash.load!(:deployment, tenant: tenant.tenant_id)

      mechanism = %DeploymentDeploy{}

      assert Core.get_operation_id(mechanism, target) == deployment.id
    end
  end

  describe "subscribe_to_operation_updates!/2 and unsubscribe_to_operation_updates!/2" do
    test "subscribes and unsubscribes to deployment updates via PubSub", %{tenant: tenant} do
      deployment = deployment_fixture(tenant: tenant)
      mechanism = %DeploymentDeploy{}

      # Subscribe to deployment updates
      assert :ok = Core.subscribe_to_operation_updates!(mechanism, deployment.id)

      # Trigger an update by marking the deployment as started
      {:ok, updated_deployment} =
        Edgehog.Containers.mark_deployment_as_stopped(deployment, tenant: tenant.tenant_id)

      topic = "deployments:#{deployment.id}"

      # Assert we receive the PubSub notification
      assert_receive %Broadcast{
        topic: ^topic,
        event: "mark_as_stopped",
        payload: %Ash.Notifier.Notification{
          data: received_deployment
        }
      }

      assert received_deployment.id == updated_deployment.id

      # Then unsubscribe
      assert :ok = Core.unsubscribe_to_operation_updates!(mechanism, deployment.id)

      # Trigger an update
      {:ok, _updated_deployment} =
        Edgehog.Containers.mark_deployment_as_started(deployment, tenant: tenant.tenant_id)

      # Should not receive any notification
      refute_receive %Broadcast{topic: ^topic}
    end
  end

  describe "fetch_next_valid_target/3" do
    test "returns the next valid target for a campaign", %{tenant: tenant} do
      campaign =
        campaign_with_targets_fixture(2,
          tenant: tenant,
          mechanism_type: :deployment_deploy
        )

      mechanism = %DeploymentDeploy{}

      assert {:ok, target} =
               Core.fetch_next_valid_target(mechanism, campaign.id, tenant.tenant_id)

      assert target.status == :idle
    end

    test "returns error when no valid targets are available", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :deployment_deploy)

      mechanism = %DeploymentDeploy{}

      assert {:error, _reason} =
               Core.fetch_next_valid_target(mechanism, campaign.id, tenant.tenant_id)
    end
  end

  describe "do_operation/2" do
    test "deploys the release to the target", %{tenant: tenant} do
      target = target_fixture(tenant: tenant, mechanism_type: :deployment_deploy)

      campaign =
        target
        |> Ash.load!(:campaign, tenant: tenant.tenant_id)
        |> Map.get(:campaign)
        |> Ash.load!(
          [
            campaign_mechanism: [
              deployment_deploy: [:release]
            ]
          ],
          tenant: tenant.tenant_id
        )

      mechanism = campaign.campaign_mechanism.value

      expect(CreateDeploymentRequestMock, :send_create_deployment_request, 1, fn _client, _device_id, _data ->
        :ok
      end)

      assert {:ok, updated_target} = Core.do_operation(mechanism, target)
      assert updated_target.id == target.id
    end
  end

  describe "retry_operation/2" do
    test "retries the deployment operation", %{tenant: tenant} do
      # Create an in-progress target which has a deployment
      target =
        [tenant: tenant]
        |> in_progress_target_fixture()
        |> Ash.load!(:campaign, tenant: tenant.tenant_id)

      campaign =
        target
        |> Map.get(:campaign)
        |> Ash.load!(
          [
            campaign_mechanism: [
              deployment_deploy: [:release]
            ]
          ],
          tenant: tenant.tenant_id
        )

      mechanism = campaign.campaign_mechanism.value

      expect(CreateDeploymentRequestMock, :send_create_deployment_request, 1, fn _client, _device_id, _data ->
        :ok
      end)

      # Now retry the operation
      assert :ok = Core.retry_operation(mechanism, target)
    end
  end

  describe "get_mechanism/2" do
    test "loads and returns the full mechanism configuration", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :deployment_deploy)

      mechanism = %DeploymentDeploy{}

      loaded_mechanism = Core.get_mechanism(mechanism, campaign)

      assert %DeploymentDeploy{} = loaded_mechanism
      assert loaded_mechanism.release
      assert loaded_mechanism.release.containers
    end
  end

  describe "integration tests" do
    test "complete flow: fetch target and deploy", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(
          tenant: tenant,
          mechanism_type: :deployment_deploy
        )
        |> Ash.load!(
          [
            campaign_mechanism: [
              deployment_deploy: [:release]
            ]
          ],
          tenant: tenant.tenant_id
        )

      mechanism = campaign.campaign_mechanism.value

      # Step 1: Fetch next valid target
      assert {:ok, target} =
               Core.fetch_next_valid_target(mechanism, campaign.id, tenant.tenant_id)

      expect(CreateDeploymentRequestMock, :send_create_deployment_request, 1, fn _client, _device_id, _data ->
        :ok
      end)

      # Step 2: Execute operation
      assert {:ok, _updated_target} = Core.do_operation(mechanism, target)
    end
  end
end
