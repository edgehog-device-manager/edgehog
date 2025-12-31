#
# This file is part of Edgehog.
#
# Copyright 2023-2025 SECO Mind Srl
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

defmodule Edgehog.Campaigns.Executors.CoreTest do
  use Edgehog.DataCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.CampaignsFixtures
  import Edgehog.TenantsFixtures

  alias Ash.Error.Invalid
  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.OTARequestV1Mock
  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.Campaign

  alias Edgehog.Campaigns.CampaignMechanism.Core.Edgehog.Campaigns.CampaignMechanism.FirmwareUpgrade,
    as: FirmwareUpgradeCore

  alias Edgehog.Campaigns.CampaignMechanism.FirmwareUpgrade
  alias Edgehog.Campaigns.CampaignTarget
  alias Edgehog.Campaigns.Executor.Lazy.Core
  # alias Edgehog.OSManagement

  setup do
    stub(OTARequestV1Mock, :update, fn _client, _device_id, _uuid, _url -> :ok end)
    %{tenant: tenant_fixture()}
  end

  describe "get_campaign!/2" do
    test "returns the the update campaign if it is present", %{tenant: tenant} do
      update_campaign = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)

      assert %Campaign{id: id, tenant_id: tenant_id, campaign_mechanism: campaign_mechanism} =
               Core.get_campaign!(tenant.tenant_id, update_campaign.id)

      assert update_campaign.id == id
      assert update_campaign.tenant_id == tenant_id
      assert update_campaign.campaign_mechanism == campaign_mechanism
    end

    test "raises for non-existing update campaign", %{tenant: tenant} do
      assert_raise Invalid, fn ->
        Core.get_campaign!(tenant.tenant_id, 12_345)
      end
    end
  end

  describe "pending_request_timeout_ms/3" do
    setup %{tenant: tenant} do
      target = target_fixture(tenant: tenant)

      %{target: target}
    end

    test "raises if latest_attempt is not set", ctx do
      campaign_mechanism = firmware_upgrade_fixture()

      assert_raise MatchError, fn ->
        Core.pending_request_timeout_ms(ctx.target, campaign_mechanism)
      end
    end

    test "returns the remaining milliseconds if the timeout is not expired", ctx do
      latest_attempt = DateTime.utc_now()

      target =
        Campaigns.update_target_latest_attempt!(ctx.target, latest_attempt)

      campaign_mechanism = firmware_upgrade_fixture(request_timeout_seconds: 5)
      time_of_check = DateTime.add(latest_attempt, 3, :second)

      assert Core.pending_request_timeout_ms(target, campaign_mechanism, time_of_check) == 2000
    end

    test "returns 0 if the timeout is already expired", ctx do
      latest_attempt = DateTime.utc_now()

      target =
        Campaigns.update_target_latest_attempt!(ctx.target, latest_attempt)

      campaign_mechanism = firmware_upgrade_fixture(request_timeout_seconds: 5)
      time_of_check = DateTime.add(latest_attempt, 10, :second)

      assert Core.pending_request_timeout_ms(target, campaign_mechanism, time_of_check) == 0
    end
  end

  test "increase_retry_count!/1", %{tenant: tenant} do
    target = target_fixture(tenant: tenant)
    new_target = Core.increase_retry_count!(target)

    assert new_target.retry_count == target.retry_count + 1
  end

  describe "can_retry?/2" do
    setup %{tenant: tenant} do
      target = target_fixture(tenant: tenant)

      %{target: target}
    end

    test "returns true if the target still has retries left", ctx do
      target = set_target_retry_count!(ctx.target, 4)
      campaign_mechanism = firmware_upgrade_fixture(request_retries: 5)

      assert Core.can_retry?(target, campaign_mechanism) == true
    end

    test "returns false if the target has no retries left", ctx do
      target = set_target_retry_count!(ctx.target, 5)
      campaign_mechanism = firmware_upgrade_fixture(request_retries: 5)

      assert Core.can_retry?(target, campaign_mechanism) == false
    end
  end

  describe "get_target!/2" do
    test "returns target if existing", %{tenant: tenant} do
      %{id: target_id} = target_fixture(tenant: tenant)

      assert %CampaignTarget{id: ^target_id} = Core.get_target!(tenant.tenant_id, target_id)
    end

    test "raises with non-existing target", %{tenant: tenant} do
      assert_raise Invalid, fn ->
        Core.get_target!(tenant.tenant_id, 1_234_567)
      end
    end
  end

  describe "get_target_for_operation!/3" do
    setup %{tenant: tenant} do
      target =
        [tenant: tenant]
        |> target_fixture()
        |> Ash.load!([:campaign | default_preloads_for_target()])

      base_image = base_image_fixture(tenant: tenant)

      %{target: target, base_image: base_image}
    end

    test "returns target with an operation if existing", ctx do
      %{
        base_image: base_image,
        target: target,
        tenant: tenant
      } = ctx

      {:ok, target} = FirmwareUpgradeCore.start_target_update(target, base_image)
      target_id = target.id

      assert %CampaignTarget{id: ^target_id} =
               Core.get_target_for_operation!(
                 tenant.tenant_id,
                 target.campaign.id,
                 target.device_id
               )
    end

    test "raises with non-existing linked target", %{tenant: tenant} do
      update_campaign = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)

      assert_raise Invalid, fn ->
        Core.get_target_for_operation!(
          tenant.tenant_id,
          update_campaign.id,
          "non_existing_device_id"
        )
      end
    end
  end

  describe "available_slots/2" do
    test "returns the number of available update slots given the current in progress count" do
      mechanism = firmware_upgrade_fixture(max_in_progress_operations: 10)
      in_progress = 7
      assert Core.available_slots(mechanism, in_progress) == 3
    end

    test "returns 0 if there are more in progress updates than allowed" do
      mechanism = firmware_upgrade_fixture(max_in_progress_operations: 5)
      in_progress = 7
      assert Core.available_slots(mechanism, in_progress) == 0
    end
  end

  test "mark_target_as_failed!/2", %{tenant: tenant} do
    completion_timestamp = ~U[2023-06-08 13:59:52.928623Z]

    target =
      [tenant: tenant]
      |> target_fixture()
      |> Core.mark_target_as_failed!(completion_timestamp)

    assert target.status == :failed
    assert target.completion_timestamp == completion_timestamp
  end

  test "mark_target_as_successful!/2", %{tenant: tenant} do
    completion_timestamp = ~U[2023-06-08 13:59:52.928623Z]

    target =
      [tenant: tenant]
      |> target_fixture()
      |> Core.mark_target_as_successful!(completion_timestamp)

    assert target.status == :successful
    assert target.completion_timestamp == completion_timestamp
  end

  describe "error_message/2" do
    setup do
      %{device_id: "LSFozZXxT0aeAdNGKrpcPg"}
    end

    test "returns specific error message for known errors", ctx do
      known_errors = [
        :version_requirement_not_matched,
        :downgrade_not_allowed,
        :ambiguous_version_ordering,
        :invalid_version,
        :missing_version,
        "connection refused",
        %APIError{status: 422, response: "Invalid entity"},
        %APIError{status: 500, response: "Internal server error"}
      ]

      for error <- known_errors do
        msg = Core.error_message(error, ctx.device_id)
        assert msg =~ ctx.device_id
        refute msg =~ "failed with unknown error"
      end
    end

    test "returns generic error message for unknown error", ctx do
      msg = Core.error_message(:a_new_kind_of_error, ctx.device_id)
      assert msg =~ ctx.device_id
      assert msg =~ "failed with unknown error"
    end
  end

  describe "temporary_error?/1" do
    test "returns true for connection refused" do
      assert Core.temporary_error?("connection refused") == true
    end

    test "returns true for API errors with status code in 500..599" do
      for status <- 500..599 do
        assert Core.temporary_error?(%APIError{status: status, response: "Error"}) === true
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
        assert Core.temporary_error?(error) == false
      end
    end

    test "returns false for unknown errors" do
      assert Core.temporary_error?(:a_new_kind_of_error) == false
    end
  end

  test "get_target_count/2", %{tenant: tenant} do
    update_campaign =
      campaign_with_targets_fixture(42, tenant: tenant, mechanism_type: :firmware_upgrade)

    assert Core.get_target_count(tenant.tenant_id, update_campaign.id) == 42
  end

  test "get_failed_target_count/2", %{tenant: tenant} do
    update_campaign =
      10
      |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
      |> Ash.load!(:campaign_targets)

    # Call start_update/2 to mark targets as in_progress
    update_campaign.campaign_targets
    |> Enum.take(7)
    |> Enum.each(&Core.mark_target_as_failed!/1)

    assert Core.get_failed_target_count(tenant.tenant_id, update_campaign.id) == 7
  end

  test "get_in_progress_target_count/2", %{tenant: tenant} do
    update_campaign =
      24
      |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
      |> Ash.load!(campaign_targets: [], campaign_mechanism: [firmware_upgrade: [:base_image]])

    # Call start_update/2 to mark targets as in_progress
    update_campaign.campaign_targets
    |> Enum.take(11)
    |> Enum.each(
      &FirmwareUpgradeCore.start_target_update(
        &1,
        update_campaign.campaign_mechanism.value.base_image
      )
    )

    assert Core.get_in_progress_target_count(tenant.tenant_id, update_campaign.id) == 11
  end

  describe "has_idle_targets?/2" do
    test "returns true for campaigns with a least one idle target", %{tenant: tenant} do
      update_campaign =
        5
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      update_campaign.campaign_targets
      |> Enum.take(4)
      |> Enum.each(&Core.mark_target_as_successful!/1)

      assert Core.has_idle_targets?(tenant.tenant_id, update_campaign.id) == true
    end

    test "returns false if all targets are in_progress", %{tenant: tenant} do
      update_campaign =
        3
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [firmware_upgrade: [:base_image]])

      # Call start_update/2 to mark targets as in_progress
      Enum.each(
        update_campaign.campaign_targets,
        &FirmwareUpgradeCore.start_target_update(
          &1,
          update_campaign.campaign_mechanism.value.base_image
        )
      )

      assert Core.has_idle_targets?(tenant.tenant_id, update_campaign.id) == false
    end

    test "returns false if all targets are successful", %{tenant: tenant} do
      update_campaign =
        3
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      Enum.each(update_campaign.campaign_targets, &Core.mark_target_as_successful!/1)

      assert Core.has_idle_targets?(tenant.tenant_id, update_campaign.id) == false
    end

    test "returns false if all targets are failed", %{tenant: tenant} do
      update_campaign =
        3
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      Enum.each(update_campaign.campaign_targets, &Core.mark_target_as_failed!/1)

      assert Core.has_idle_targets?(tenant.tenant_id, update_campaign.id) == false
    end

    test "returns false if campaign has no targets", %{tenant: tenant} do
      update_campaign =
        [tenant: tenant, mechanism_type: :firmware_upgrade]
        |> campaign_fixture()
        |> Ash.load!(:campaign_targets)

      assert update_campaign.campaign_targets == []
      assert Core.has_idle_targets?(tenant.tenant_id, update_campaign.id) == false
    end
  end

  test "mark_campaign_in_progress!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    assert %Campaign{status: :in_progress, start_timestamp: ^now} =
             3
             |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
             |> Core.mark_campaign_in_progress!(now)
  end

  test "mark_campaign_as_failed!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    assert %Campaign{status: :finished, outcome: :failure, completion_timestamp: ^now} =
             3
             |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
             |> Core.mark_campaign_as_failed!(now)
  end

  test "mark_campaign_as_successful!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    assert %Campaign{status: :finished, outcome: :success, completion_timestamp: ^now} =
             3
             |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
             |> Core.mark_campaign_as_successful!(now)
  end

  describe "list_in_progress_targets/1" do
    test "returns empty list if no target has pending ota operations", %{tenant: tenant} do
      update_campaign =
        5
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      assert [] == Core.list_in_progress_targets(tenant.tenant_id, update_campaign.id)
    end

    test "returns target if it has a pending OTA Operation", %{tenant: tenant} do
      update_campaign =
        5
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [firmware_upgrade: [:base_image]])

      assert {:ok, target} =
               update_campaign.campaign_targets
               |> hd()
               |> FirmwareUpgradeCore.start_target_update(update_campaign.campaign_mechanism.value.base_image)

      assert [pending_ota_operation_target] =
               Core.list_in_progress_targets(tenant.tenant_id, update_campaign.id)

      assert pending_ota_operation_target.id == target.id
    end

    # ????????????????????????????????????????????????//
    # test "does not return target if its OTA Operation is in a different state", %{tenant: tenant} do
    #   update_campaign =
    #     5
    #     |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
    #     |> Ash.load!(campaign_targets: [], campaign_mechanism: [firmware_upgrade: [:base_image]])

    #   assert {:ok, target} =
    #            update_campaign.campaign_targets
    #            |> hd()
    #            |> Ash.load!(default_preloads_for_target())
    #            |> FirmwareUpgradeCore.start_target_update(update_campaign.campaign_mechanism.value.base_image)

    #   assert {:ok, _ota_operation} =
    #            target.ota_operation_id
    #            |> OSManagement.fetch_ota_operation!(tenant: tenant)
    #            |> OSManagement.update_ota_operation_status(:acknowledged)

    #   assert [] ==
    #            Core.list_in_progress_targets(tenant.tenant_id, update_campaign.id)
    # end
  end

  defp firmware_upgrade_fixture(attrs \\ []) do
    attrs
    |> Enum.into(%{
      max_failure_percentage: 5.0,
      max_in_progress_operations: 10,
      force_downgrade: false,
      request_retries: 0,
      request_timeout_seconds: 60
    })
    |> then(&struct!(FirmwareUpgrade, &1))
  end

  defp set_target_retry_count!(target, count) do
    assert target.retry_count == 0
    Enum.reduce(1..count, target, fn _idx, target -> Core.increase_retry_count!(target) end)
  end

  defp default_preloads_for_target do
    [
      ota_operation: [:status],
      device: [realm: [:cluster]]
    ]
  end
end
