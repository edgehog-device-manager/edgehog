#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Campaigns.CampaignMechanism.DeploymentDeployCoreTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures
  import Mox

  alias Ash.Error.Invalid
  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.CreateDeploymentRequestMock
  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.CampaignMechanism.Core, as: MechanismCore
  alias Edgehog.Campaigns.CampaignMechanism.DeploymentDeploy
  alias Edgehog.Campaigns.CampaignTarget
  alias Phoenix.Socket.Broadcast

  setup :verify_on_exit!

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "get_operation_id/2" do
    test "returns nil when target has no deployment", %{tenant: tenant} do
      target = target_fixture(tenant: tenant, mechanism_type: :deployment_deploy)

      mechanism = %DeploymentDeploy{}

      assert MechanismCore.get_operation_id(mechanism, target) == nil
    end

    test "returns deployment_id when target has deployment", %{tenant: tenant} do
      deployment = deployment_fixture(tenant: tenant)

      target =
        [tenant: tenant, mechanism_type: :deployment_deploy]
        |> target_fixture()
        |> Campaigns.set_target_deployment(deployment.id, tenant: tenant.tenant_id)
        |> Ash.load!(:deployment, tenant: tenant.tenant_id)

      mechanism = %DeploymentDeploy{}

      assert MechanismCore.get_operation_id(mechanism, target) == deployment.id
    end
  end

  describe "subscribe_to_operation_updates!/2 and unsubscribe_to_operation_updates!/2" do
    test "subscribes and unsubscribes to deployment updates via PubSub", %{tenant: tenant} do
      deployment = deployment_fixture(tenant: tenant)
      mechanism = %DeploymentDeploy{}

      # Subscribe to deployment updates
      assert :ok = MechanismCore.subscribe_to_operation_updates!(mechanism, deployment.id)

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
      assert :ok = MechanismCore.unsubscribe_to_operation_updates!(mechanism, deployment.id)

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
               MechanismCore.fetch_next_valid_target(mechanism, campaign.id, tenant.tenant_id)

      assert target.status == :idle
    end

    test "returns error when no valid targets are available", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :deployment_deploy)

      mechanism = %DeploymentDeploy{}

      assert {:error, _reason} =
               MechanismCore.fetch_next_valid_target(mechanism, campaign.id, tenant.tenant_id)
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

      assert {:ok, updated_target} = MechanismCore.do_operation(mechanism, target)
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
      assert :ok = MechanismCore.retry_operation(mechanism, target)
    end
  end

  describe "get_mechanism/2" do
    test "loads and returns the full mechanism configuration", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :deployment_deploy)

      mechanism = %DeploymentDeploy{}

      loaded_mechanism = MechanismCore.get_mechanism(mechanism, campaign)

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
               MechanismCore.fetch_next_valid_target(mechanism, campaign.id, tenant.tenant_id)

      expect(CreateDeploymentRequestMock, :send_create_deployment_request, 1, fn _client, _device_id, _data ->
        :ok
      end)

      # Step 2: Execute operation
      assert {:ok, _updated_target} = MechanismCore.do_operation(mechanism, target)
    end
  end

  describe "get_campaign!/2" do
    test "returns the the update campaign if it is present", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :deployment_deploy)
      mechanism = campaign.campaign_mechanism.value

      assert %Campaign{id: id, tenant_id: tenant_id, campaign_mechanism: campaign_mechanism} =
               MechanismCore.get_campaign!(mechanism, tenant.tenant_id, campaign.id)

      assert campaign.id == id
      assert campaign.tenant_id == tenant_id
      assert campaign.campaign_mechanism == campaign_mechanism
    end

    test "raises for non-existing campaign", %{tenant: tenant} do
      assert_raise Invalid, fn ->
        MechanismCore.get_campaign!(Any, tenant.tenant_id, 12_345)
      end
    end
  end

  describe "pending_request_timeout_ms/3" do
    setup %{tenant: tenant} do
      target = target_fixture(tenant: tenant)

      %{target: target}
    end

    test "raises if latest_attempt is not set", ctx do
      campaign_mechanism = deployment_deploy_mechanism_fixture()

      assert_raise MatchError, fn ->
        MechanismCore.pending_request_timeout_ms(campaign_mechanism, ctx.target)
      end
    end

    test "returns the remaining milliseconds if the timeout is not expired", ctx do
      latest_attempt = DateTime.utc_now()

      target =
        Campaigns.update_target_latest_attempt!(ctx.target, latest_attempt)

      campaign_mechanism = deployment_deploy_mechanism_fixture(request_timeout_seconds: 5)
      time_of_check = DateTime.add(latest_attempt, 3, :second)

      assert MechanismCore.pending_request_timeout_ms(campaign_mechanism, target, time_of_check) ==
               2000
    end

    test "returns 0 if the timeout is already expired", ctx do
      latest_attempt = DateTime.utc_now()

      target =
        Campaigns.update_target_latest_attempt!(ctx.target, latest_attempt)

      campaign_mechanism = deployment_deploy_mechanism_fixture(request_timeout_seconds: 5)
      time_of_check = DateTime.add(latest_attempt, 10, :second)

      assert MechanismCore.pending_request_timeout_ms(campaign_mechanism, target, time_of_check) ==
               0
    end
  end

  test "increase_retry_count!/1", %{tenant: tenant} do
    target = target_fixture(tenant: tenant)
    new_target = MechanismCore.increase_retry_count!(%DeploymentDeploy{}, target)

    assert new_target.retry_count == target.retry_count + 1
  end

  describe "can_retry?/2" do
    setup %{tenant: tenant} do
      target = target_fixture(tenant: tenant)

      %{target: target}
    end

    test "returns true if the target still has retries left", ctx do
      target = set_target_retry_count!(ctx.target, 4)
      campaign_mechanism = deployment_deploy_mechanism_fixture(request_retries: 5)

      assert MechanismCore.can_retry?(campaign_mechanism, target) == true
    end

    test "returns false if the target has no retries left", ctx do
      target = set_target_retry_count!(ctx.target, 5)
      campaign_mechanism = deployment_deploy_mechanism_fixture(request_retries: 5)

      assert MechanismCore.can_retry?(campaign_mechanism, target) == false
    end
  end

  describe "get_target!/2" do
    test "returns target if existing", %{tenant: tenant} do
      %{id: target_id} = target_fixture(tenant: tenant)

      assert %CampaignTarget{id: ^target_id} =
               MechanismCore.get_target!(%DeploymentDeploy{}, tenant.tenant_id, target_id)
    end

    test "raises with non-existing target", %{tenant: tenant} do
      assert_raise Invalid, fn ->
        MechanismCore.get_target!(%DeploymentDeploy{}, tenant.tenant_id, 1_234_567)
      end
    end
  end

  describe "get_target_for_operation!/3" do
    setup %{tenant: tenant} do
      target =
        [tenant: tenant]
        |> target_fixture()
        |> Ash.load!([:campaign | default_preloads_for_target()])

      release = release_fixture(tenant: tenant)

      %{target: target, release: release}
    end

    test "returns target with an operation if existing", ctx do
      %{
        release: release,
        target: target,
        tenant: tenant
      } = ctx

      {:ok, target} = Campaigns.link_deployment(target, release, tenant: tenant.tenant_id)
      target_id = target.id

      assert %CampaignTarget{id: ^target_id} =
               MechanismCore.get_target_for_operation!(
                 %DeploymentDeploy{},
                 tenant.tenant_id,
                 target.campaign.id,
                 target.device_id
               )
    end

    test "raises with non-existing linked target", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :deployment_deploy)

      assert_raise Invalid, fn ->
        MechanismCore.get_target_for_operation!(
          %DeploymentDeploy{},
          tenant.tenant_id,
          campaign.id,
          "non_existing_device_id"
        )
      end
    end
  end

  describe "available_slots/2" do
    test "returns the number of available update slots given the current in progress count" do
      mechanism = deployment_deploy_mechanism_fixture(max_in_progress_operations: 10)
      in_progress = 7
      assert MechanismCore.available_slots(mechanism, in_progress) == 3
    end

    test "returns 0 if there are more in progress updates than allowed" do
      mechanism = deployment_deploy_mechanism_fixture(max_in_progress_operations: 5)
      in_progress = 7
      assert MechanismCore.available_slots(mechanism, in_progress) == 0
    end
  end

  test "mark_target_as_failed!/2", %{tenant: tenant} do
    completion_timestamp = ~U[2023-06-08 13:59:52.928623Z]

    target = target_fixture(tenant: tenant)

    target =
      MechanismCore.mark_target_as_failed!(%DeploymentDeploy{}, target, completion_timestamp)

    assert target.status == :failed
    assert target.completion_timestamp == completion_timestamp
  end

  test "mark_target_as_successful!/2", %{tenant: tenant} do
    completion_timestamp = ~U[2023-06-08 13:59:52.928623Z]

    target = target_fixture(tenant: tenant)

    target =
      MechanismCore.mark_target_as_successful!(%DeploymentDeploy{}, target, completion_timestamp)

    assert target.status == :successful
    assert target.completion_timestamp == completion_timestamp
  end

  describe "error_message/3" do
    setup do
      %{device_id: "LSFozZXxT0aeAdNGKrpcPg"}
    end

    test "returns specific error message for known errors", ctx do
      known_errors = [
        "connection refused",
        %APIError{status: 422, response: "Invalid entity"},
        %APIError{status: 500, response: "Internal server error"}
      ]

      for error <- known_errors do
        msg = MechanismCore.error_message(%DeploymentDeploy{}, error, ctx.device_id)
        assert msg =~ ctx.device_id
        refute msg =~ "failed with unknown error"
      end
    end

    test "returns generic error message for unknown error", ctx do
      msg = MechanismCore.error_message(%DeploymentDeploy{}, :a_new_kind_of_error, ctx.device_id)
      assert msg =~ ctx.device_id
      assert msg =~ "failed with unknown error"
    end
  end

  describe "temporary_error?/1" do
    test "returns true for connection refused" do
      assert MechanismCore.temporary_error?(%DeploymentDeploy{}, "connection refused") == true
    end

    test "returns true for API errors with status code in 500..599" do
      for status <- 500..599 do
        assert MechanismCore.temporary_error?(%DeploymentDeploy{}, %APIError{
                 status: status,
                 response: "Error"
               }) ===
                 true
      end
    end

    test "returns false for known non temporary errors" do
      known_non_temporary_errors = [
        :version_requirement_not_matched,
        :downgrade_not_allowed,
        :ambiguous_version_ordering,
        :invalid_version,
        :missing_version,
        %APIError{status: 404, response: "Not found"}
      ]

      for error <- known_non_temporary_errors do
        assert MechanismCore.temporary_error?(%DeploymentDeploy{}, error) == false
      end
    end

    test "returns false for unknown errors" do
      assert MechanismCore.temporary_error?(%DeploymentDeploy{}, :a_new_kind_of_error) == false
    end
  end

  test "get_target_count/2", %{tenant: tenant} do
    campaign =
      campaign_with_targets_fixture(42, tenant: tenant, mechanism_type: :deployment_deploy)

    assert MechanismCore.get_target_count(%DeploymentDeploy{}, tenant.tenant_id, campaign.id) ==
             42
  end

  test "get_failed_target_count/2", %{tenant: tenant} do
    campaign =
      10
      |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_deploy)
      |> Ash.load!(:campaign_targets)

    campaign.campaign_targets
    |> Enum.take(7)
    |> Enum.each(fn target ->
      MechanismCore.mark_target_as_failed!(%DeploymentDeploy{}, target)
    end)

    assert MechanismCore.get_failed_target_count(
             %DeploymentDeploy{},
             tenant.tenant_id,
             campaign.id
           ) == 7
  end

  test "get_in_progress_target_count/2", %{tenant: tenant} do
    campaign =
      24
      |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_deploy)
      |> Ash.load!(campaign_targets: [], campaign_mechanism: [deployment_deploy: [:release]])

    # Call start_update/2 to mark targets as in_progress
    campaign.campaign_targets
    |> Enum.take(11)
    |> Enum.each(
      &Campaigns.link_deployment(
        &1,
        campaign.campaign_mechanism.value.release
      )
    )

    assert MechanismCore.get_in_progress_target_count(
             %DeploymentDeploy{},
             tenant.tenant_id,
             campaign.id
           ) == 11
  end

  describe "has_idle_targets?/2" do
    test "returns true for campaigns with a least one idle target", %{tenant: tenant} do
      campaign =
        5
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_deploy)
        |> Ash.load!(:campaign_targets)

      campaign.campaign_targets
      |> Enum.take(4)
      |> Enum.each(fn target ->
        MechanismCore.mark_target_as_successful!(%DeploymentDeploy{}, target)
      end)

      assert MechanismCore.has_idle_targets?(%DeploymentDeploy{}, tenant.tenant_id, campaign.id) ==
               true
    end

    test "returns false if all targets are in_progress", %{tenant: tenant} do
      campaign =
        3
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_deploy)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [deployment_deploy: [:release]])

      # Call start_update/2 to mark targets as in_progress
      Enum.each(
        campaign.campaign_targets,
        &Campaigns.link_deployment(
          &1,
          campaign.campaign_mechanism.value.release
        )
      )

      assert MechanismCore.has_idle_targets?(%DeploymentDeploy{}, tenant.tenant_id, campaign.id) ==
               false
    end

    test "returns false if all targets are successful", %{tenant: tenant} do
      campaign =
        3
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_deploy)
        |> Ash.load!(:campaign_targets)

      Enum.each(campaign.campaign_targets, fn target ->
        MechanismCore.mark_target_as_successful!(%DeploymentDeploy{}, target)
      end)

      assert MechanismCore.has_idle_targets?(%DeploymentDeploy{}, tenant.tenant_id, campaign.id) ==
               false
    end

    test "returns false if all targets are failed", %{tenant: tenant} do
      campaign =
        3
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_deploy)
        |> Ash.load!(:campaign_targets)

      Enum.each(campaign.campaign_targets, fn target ->
        MechanismCore.mark_target_as_failed!(%DeploymentDeploy{}, target)
      end)

      assert MechanismCore.has_idle_targets?(%DeploymentDeploy{}, tenant.tenant_id, campaign.id) ==
               false
    end

    test "returns false if campaign has no targets", %{tenant: tenant} do
      campaign =
        [tenant: tenant, mechanism_type: :deployment_deploy]
        |> campaign_fixture()
        |> Ash.load!(:campaign_targets)

      assert campaign.campaign_targets == []

      assert MechanismCore.has_idle_targets?(%DeploymentDeploy{}, tenant.tenant_id, campaign.id) ==
               false
    end
  end

  test "mark_campaign_in_progress!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    campaign =
      campaign_with_targets_fixture(3, tenant: tenant, mechanism_type: :deployment_deploy)

    assert %Campaign{status: :in_progress, start_timestamp: ^now} =
             MechanismCore.mark_campaign_in_progress!(%DeploymentDeploy{}, campaign, now)
  end

  test "mark_campaign_as_failed!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    campaign =
      campaign_with_targets_fixture(3, tenant: tenant, mechanism_type: :deployment_deploy)

    assert %Campaign{status: :finished, outcome: :failure, completion_timestamp: ^now} =
             MechanismCore.mark_campaign_as_failed!(%DeploymentDeploy{}, campaign, now)
  end

  test "mark_campaign_as_successful!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    campaign =
      campaign_with_targets_fixture(3, tenant: tenant, mechanism_type: :deployment_deploy)

    assert %Campaign{status: :finished, outcome: :success, completion_timestamp: ^now} =
             MechanismCore.mark_campaign_as_successful!(%DeploymentDeploy{}, campaign, now)
  end

  describe "list_in_progress_targets/1" do
    test "returns empty list if no target has pending ota operations", %{tenant: tenant} do
      campaign =
        5
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_deploy)
        |> Ash.load!(:campaign_targets)

      assert [] ==
               MechanismCore.list_in_progress_targets(
                 %DeploymentDeploy{},
                 tenant.tenant_id,
                 campaign.id
               )
    end

    test "returns target if it has a pending Deployment", %{tenant: tenant} do
      campaign =
        5
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_deploy)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [deployment_deploy: [:release]])

      assert {:ok, target} =
               campaign.campaign_targets
               |> hd()
               |> Campaigns.link_deployment(campaign.campaign_mechanism.value.release)

      assert [pending_ota_operation_target] =
               MechanismCore.list_in_progress_targets(
                 %DeploymentDeploy{},
                 tenant.tenant_id,
                 campaign.id
               )

      assert pending_ota_operation_target.id == target.id
    end
  end

  defp deployment_deploy_mechanism_fixture(attrs \\ []) do
    attrs
    |> Enum.into(%{
      max_failure_percentage: 5.0,
      max_in_progress_operations: 10,
      request_retries: 0,
      request_timeout_seconds: 60
    })
    |> then(&struct!(DeploymentDeploy, &1))
  end

  defp set_target_retry_count!(target, count) do
    assert target.retry_count == 0

    Enum.reduce(1..count, target, fn _idx, target ->
      MechanismCore.increase_retry_count!(%DeploymentDeploy{}, target)
    end)
  end

  defp default_preloads_for_target do
    [
      deployment: [:state],
      device: [realm: [:cluster]]
    ]
  end
end
