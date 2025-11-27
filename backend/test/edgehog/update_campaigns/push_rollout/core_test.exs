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

defmodule Edgehog.UpdateCampaigns.PushRollout.CoreTest do
  use Edgehog.DataCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.OSManagementFixtures
  import Edgehog.TenantsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Ash.Error.Invalid
  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.BaseImage
  alias Edgehog.Astarte.Device.BaseImageMock
  alias Edgehog.Astarte.Device.OTARequestV1Mock
  alias Edgehog.Error.AstarteAPIError
  alias Edgehog.OSManagement
  alias Edgehog.OSManagement.OTAOperation
  alias Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout
  alias Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout.Core
  alias Edgehog.UpdateCampaigns.UpdateCampaign
  alias Edgehog.UpdateCampaigns.UpdateTarget

  setup do
    stub(OTARequestV1Mock, :update, fn _client, _device_id, _uuid, _url -> :ok end)
    %{tenant: tenant_fixture()}
  end

  describe "get_update_campaign!/2" do
    test "returns the the update campaign if it is present", %{tenant: tenant} do
      update_campaign = update_campaign_fixture(tenant: tenant)

      assert %UpdateCampaign{id: id, tenant_id: tenant_id, rollout_mechanism: rollout_mechanism} =
               Core.get_update_campaign!(tenant.tenant_id, update_campaign.id)

      assert update_campaign.id == id
      assert update_campaign.tenant_id == tenant_id
      assert update_campaign.rollout_mechanism == rollout_mechanism
    end

    test "raises for non-existing update campaign", %{tenant: tenant} do
      assert_raise Invalid, fn ->
        Core.get_update_campaign!(tenant.tenant_id, 12_345)
      end
    end
  end

  describe "get_update_campaign_base_image!/2" do
    test "returns the base image if the update campaign is present", %{tenant: tenant} do
      update_campaign = update_campaign_fixture(tenant: tenant)

      base_image = Core.get_update_campaign_base_image!(tenant.tenant_id, update_campaign.id)

      assert base_image.id == update_campaign.base_image.id
      assert base_image.url == update_campaign.base_image.url
      assert base_image.version == update_campaign.base_image.version

      assert base_image.starting_version_requirement ==
               update_campaign.base_image.starting_version_requirement
    end

    test "raises for non-existing update campaign", %{tenant: tenant} do
      assert_raise Invalid, fn ->
        Core.get_update_campaign_base_image!(tenant.tenant_id, 12_345)
      end
    end
  end

  test "update_target_latest_attempt!/2", %{tenant: tenant} do
    latest_attempt = ~U[2023-06-06 16:19:44.404358Z]

    target =
      [tenant: tenant]
      |> target_fixture()
      |> Core.update_target_latest_attempt!(latest_attempt)

    assert target.latest_attempt == latest_attempt
  end

  describe "pending_request_timeout_ms/3" do
    setup %{tenant: tenant} do
      target = target_fixture(tenant: tenant)

      %{target: target}
    end

    test "raises if latest_attempt is not set", ctx do
      rollout_mechanism = push_rollout_fixture()

      assert_raise MatchError, fn ->
        Core.pending_request_timeout_ms(ctx.target, rollout_mechanism)
      end
    end

    test "returns the remaining milliseconds if the timeout is not expired", ctx do
      latest_attempt = DateTime.utc_now()

      target =
        Core.update_target_latest_attempt!(ctx.target, latest_attempt)

      rollout_mechanism = push_rollout_fixture(ota_request_timeout_seconds: 5)
      time_of_check = DateTime.add(latest_attempt, 3, :second)

      assert Core.pending_request_timeout_ms(target, rollout_mechanism, time_of_check) == 2000
    end

    test "returns 0 if the timeout is already expired", ctx do
      latest_attempt = DateTime.utc_now()

      target =
        Core.update_target_latest_attempt!(ctx.target, latest_attempt)

      rollout_mechanism = push_rollout_fixture(ota_request_timeout_seconds: 5)
      time_of_check = DateTime.add(latest_attempt, 10, :second)

      assert Core.pending_request_timeout_ms(target, rollout_mechanism, time_of_check) == 0
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
      rollout_mechanism = push_rollout_fixture(ota_request_retries: 5)

      assert Core.can_retry?(target, rollout_mechanism) == true
    end

    test "returns false if the target has no retries left", ctx do
      target = set_target_retry_count!(ctx.target, 5)
      rollout_mechanism = push_rollout_fixture(ota_request_retries: 5)

      assert Core.can_retry?(target, rollout_mechanism) == false
    end
  end

  describe "retry_target_update/1" do
    setup %{tenant: tenant} do
      target =
        [tenant: tenant]
        |> in_progress_target_fixture()
        |> Ash.load!(Core.default_preloads_for_target())

      base_image = base_image_fixture(tenant: tenant)

      %{target: target, base_image: base_image}
    end

    test "succeeds if Astarte API replies with a success", ctx do
      %{
        base_image: base_image,
        target: target
      } = ctx

      expect(OTARequestV1Mock, :update, fn _client, device_id, _uuid, url ->
        assert device_id == target.device.device_id
        assert url == base_image.url
        :ok
      end)

      assert :ok = Core.retry_target_update(target)
    end

    test "fails if Astarte API replies with a failure", ctx do
      %{
        base_image: base_image,
        target: target
      } = ctx

      expect(OTARequestV1Mock, :update, fn _client, device_id, _uuid, url ->
        assert device_id == target.device.device_id
        assert url == base_image.url
        {:error, %APIError{status: 500, response: "Internal server error"}}
      end)

      assert {:error, reason} = Core.retry_target_update(target)

      assert %Invalid{
               errors: [
                 %AstarteAPIError{status: 500, response: "Internal server error"}
               ]
             } = reason
    end
  end

  describe "get_target!/2" do
    test "returns target if existing", %{tenant: tenant} do
      %{id: target_id} = target_fixture(tenant: tenant)

      assert %UpdateTarget{id: ^target_id} = Core.get_target!(tenant.tenant_id, target_id)
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
        |> Ash.load!([:update_campaign | Core.default_preloads_for_target()])

      base_image = base_image_fixture(tenant: tenant)

      %{target: target, base_image: base_image}
    end

    test "returns target with an operation if existing", ctx do
      %{
        base_image: base_image,
        target: target,
        tenant: tenant
      } = ctx

      {:ok, target} = Core.start_target_update(target, base_image)
      target_id = target.id

      assert %UpdateTarget{id: ^target_id} =
               Core.get_target_for_operation!(
                 tenant.tenant_id,
                 target.update_campaign.id,
                 target.device_id
               )
    end

    test "raises with non-existing linked target", %{tenant: tenant} do
      update_campaign = update_campaign_fixture(tenant: tenant)

      assert_raise Invalid, fn ->
        Core.get_target_for_operation!(
          tenant.tenant_id,
          update_campaign.id,
          "non_existing_device_id"
        )
      end
    end
  end

  describe "start_target_update/2" do
    setup %{tenant: tenant} do
      target =
        [tenant: tenant]
        |> target_fixture()
        |> Ash.load!(Core.default_preloads_for_target())

      base_image = base_image_fixture(tenant: tenant)

      %{target: target, base_image: base_image}
    end

    test "succeeds if Astarte API replies with a success", ctx do
      %{
        base_image: base_image,
        target: target
      } = ctx

      expect(OTARequestV1Mock, :update, fn _client, device_id, _uuid, url ->
        assert device_id == target.device.device_id
        assert url == base_image.url
        :ok
      end)

      assert {:ok, target} = Core.start_target_update(target, base_image)
      assert target.status == :in_progress
      assert target.ota_operation_id
    end

    test "fails if Astarte API replies with a failure", ctx do
      %{
        base_image: base_image,
        target: target
      } = ctx

      expect(OTARequestV1Mock, :update, fn _client, device_id, _uuid, url ->
        assert device_id == target.device.device_id
        assert url == base_image.url
        {:error, %APIError{status: 500, response: "Internal server error"}}
      end)

      assert {:error, reason} = Core.start_target_update(target, base_image)

      assert %Invalid{
               errors: [
                 %AstarteAPIError{status: 500, response: "Internal server error"}
               ]
             } = reason

      assert target.status == :idle
    end
  end

  describe "available_slots/2" do
    test "returns the number of available update slots given the current in progress count" do
      rollout = push_rollout_fixture(max_in_progress_updates: 10)
      in_progress = 7
      assert Core.available_slots(rollout, in_progress) == 3
    end

    test "returns 0 if there are more in progress updates than allowed" do
      rollout = push_rollout_fixture(max_in_progress_updates: 5)
      in_progress = 7
      assert Core.available_slots(rollout, in_progress) == 0
    end
  end

  describe "fetch_target_current_version/1" do
    setup %{tenant: tenant} do
      target =
        [tenant: tenant]
        |> target_fixture()
        |> Ash.load!(Core.default_preloads_for_target())

      %{target: target}
    end

    test "returns the version if Astarte API replies with a success", ctx do
      %{target: target} = ctx

      expect(BaseImageMock, :get, fn _client, device_id ->
        assert device_id == target.device.device_id

        base_image = %BaseImage{
          name: "esp-idf",
          version: "4.3.1",
          build_id: "2022-01-01 12:00:00",
          fingerprint: "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3"
        }

        {:ok, base_image}
      end)

      assert {:ok, version} = Core.fetch_target_current_version(target)
      assert Version.compare(version, "4.3.1") == :eq
    end

    test "returns error if the Astarte API replies with an error", ctx do
      %{target: target} = ctx

      expect(BaseImageMock, :get, fn _client, _device_id ->
        {:error, %APIError{status: 500, response: "Internal server error"}}
      end)

      assert {:error, :missing_version} = Core.fetch_target_current_version(target)
    end

    test "returns error if the returned version is invalid", ctx do
      %{target: target} = ctx

      expect(BaseImageMock, :get, fn _client, _device_id ->
        base_image = %BaseImage{
          name: "esp-idf",
          version: "3.not-a-valid-semver",
          build_id: "2022-01-01 12:00:00",
          fingerprint: "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3"
        }

        {:ok, base_image}
      end)

      assert {:error, :invalid_version} = Core.fetch_target_current_version(target)
    end

    test "returns error if the returned version is empty", ctx do
      %{target: target} = ctx

      expect(BaseImageMock, :get, fn _client, _device_id ->
        base_image = %BaseImage{
          name: "esp-idf",
          version: nil,
          build_id: "2022-01-01 12:00:00",
          fingerprint: "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3"
        }

        {:ok, base_image}
      end)

      assert {:error, :missing_version} = Core.fetch_target_current_version(target)
    end
  end

  describe "needs_update?/2" do
    test "returns true if the target has a different version from the base image", %{
      tenant: tenant
    } do
      base_image = base_image_fixture(version: "1.1.0", tenant: tenant)
      target_current_version = Version.parse!("1.0.0")

      assert Core.needs_update?(target_current_version, base_image) == true
    end

    test "returns true if the target has a different build segment from the base image", %{
      tenant: tenant
    } do
      base_image = base_image_fixture(version: "1.1.0+build1", tenant: tenant)
      target_current_version = Version.parse!("1.1.0+build0")

      assert Core.needs_update?(target_current_version, base_image) == true
    end

    test "returns false if the target has exactly the same version as the base image", %{
      tenant: tenant
    } do
      base_image = base_image_fixture(version: "1.3.4-beta.0+build1", tenant: tenant)
      target_current_version = Version.parse!(base_image.version)

      assert Core.needs_update?(target_current_version, base_image) == false
    end
  end

  describe "verify_compatibility/2" do
    test "returns error when trying to downgrade and force_downgrade: false", %{tenant: tenant} do
      base_image = base_image_fixture(version: "1.1.0", tenant: tenant)
      target_current_version = Version.parse!("1.2.0")
      rollout = push_rollout_fixture(force_downgrade: false)

      assert Core.verify_compatibility(target_current_version, base_image, rollout) ==
               {:error, :downgrade_not_allowed}
    end

    test "returns error when passing same version with different build segment and force_downgrade: false",
         %{tenant: tenant} do
      base_image = base_image_fixture(version: "1.1.0+build0", tenant: tenant)
      target_current_version = Version.parse!("1.1.0+build1")
      rollout = push_rollout_fixture(force_downgrade: false)

      assert Core.verify_compatibility(target_current_version, base_image, rollout) ==
               {:error, :ambiguous_version_ordering}
    end

    test "returns :ok when downgrading with force_downgrade: true", %{tenant: tenant} do
      base_image = base_image_fixture(version: "1.1.0", tenant: tenant)
      target_current_version = Version.parse!("1.2.0")
      rollout = push_rollout_fixture(force_downgrade: true)

      assert Core.verify_compatibility(target_current_version, base_image, rollout) == :ok
    end

    test "returns error when version is not compatible with starting version requirement", %{
      tenant: tenant
    } do
      base_image =
        base_image_fixture(
          version: "2.3.0",
          starting_version_requirement: ">= 2.0.0",
          tenant: tenant
        )

      target_current_version = Version.parse!("1.7.0")
      rollout = push_rollout_fixture()

      assert Core.verify_compatibility(target_current_version, base_image, rollout) ==
               {:error, :version_requirement_not_matched}
    end

    test "returns :ok when version is compatible with starting version requirement", %{
      tenant: tenant
    } do
      base_image =
        base_image_fixture(
          version: "2.3.0",
          starting_version_requirement: "~> 2.1",
          tenant: tenant
        )

      target_current_version = Version.parse!("2.2.3")
      rollout = push_rollout_fixture()

      assert Core.verify_compatibility(target_current_version, base_image, rollout) == :ok
    end
  end

  test "mark_operation_as_timed_out!/2", %{tenant: tenant} do
    base_image = base_image_fixture(tenant: tenant)

    {:ok, target} =
      [tenant: tenant]
      |> target_fixture()
      |> Ash.load!(Core.default_preloads_for_target())
      |> Core.start_target_update(base_image)

    ota_operation =
      Core.mark_operation_as_timed_out!(tenant.tenant_id, target.ota_operation_id)

    assert ota_operation.status == :failure
    assert ota_operation.status_code == :request_timeout
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

  describe "fetch_next_updatable_target/2" do
    test "does not return :pending targets", %{tenant: tenant} do
      update_campaign =
        1 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      [pending_target] = update_campaign.update_targets

      pending_target
      |> Ash.load!(Core.default_preloads_for_target())
      |> Core.start_target_update(update_campaign.base_image)

      assert {:error, %Invalid{}} =
               Core.fetch_next_updatable_target(tenant.tenant_id, update_campaign.id)
    end

    test "does not return :successful targets", %{tenant: tenant} do
      update_campaign =
        1 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      [successful_target] = update_campaign.update_targets

      successful_target
      |> Ash.load!(Core.default_preloads_for_target())
      |> Core.mark_target_as_successful!()

      assert {:error, %Invalid{}} =
               Core.fetch_next_updatable_target(tenant.tenant_id, update_campaign.id)
    end

    test "does not return :failed targets", %{tenant: tenant} do
      update_campaign =
        1 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      [failed_target] = update_campaign.update_targets

      failed_target
      |> Ash.load!(Core.default_preloads_for_target())
      |> Core.mark_target_as_failed!()

      assert {:error, %Invalid{}} =
               Core.fetch_next_updatable_target(tenant.tenant_id, update_campaign.id)
    end

    test "only returns online targets", %{tenant: tenant} do
      update_campaign =
        1 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      [target] = update_campaign.update_targets

      target
      |> Ash.load!(Core.default_preloads_for_target())
      |> update_device_online_for_target!(false)

      assert {:error, %Invalid{}} =
               Core.fetch_next_updatable_target(tenant.tenant_id, update_campaign.id)

      target
      |> Ash.load!(Core.default_preloads_for_target())
      |> update_device_online_for_target!(true)

      assert {:ok, online_target} =
               Core.fetch_next_updatable_target(tenant.tenant_id, update_campaign.id)

      assert target.id == online_target.id
    end

    test "returns targets without any attempts first", %{tenant: tenant} do
      update_campaign =
        2 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      [target_with_attempt, target_with_no_attempt] = update_campaign.update_targets

      Core.update_target_latest_attempt!(target_with_attempt, DateTime.utc_now())

      assert {:ok, target} =
               Core.fetch_next_updatable_target(tenant.tenant_id, update_campaign.id)

      assert target.id == target_with_no_attempt.id
    end

    test "returns targets with oldest attempt first", %{tenant: tenant} do
      update_campaign =
        2 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      [target_with_old_attempt, target_with_recent_attempt] = update_campaign.update_targets

      recent_attempt_timestamp = DateTime.utc_now()
      Core.update_target_latest_attempt!(target_with_recent_attempt, recent_attempt_timestamp)

      old_attempt_timestamp = DateTime.add(recent_attempt_timestamp, -10, :hour)
      Core.update_target_latest_attempt!(target_with_old_attempt, old_attempt_timestamp)

      assert {:ok, target} =
               Core.fetch_next_updatable_target(tenant.tenant_id, update_campaign.id)

      assert target.id == target_with_old_attempt.id
    end

    test "returns {:error, :no_updatable_targets} with no updatable targets", %{tenant: tenant} do
      update_campaign =
        2 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      [successful_target, offline_target] = update_campaign.update_targets

      successful_target
      |> Ash.load!(Core.default_preloads_for_target())
      |> Core.mark_target_as_successful!()

      offline_target
      |> Ash.load!(Core.default_preloads_for_target())
      |> update_device_online_for_target!(false)

      assert {:error, %Invalid{}} =
               Core.fetch_next_updatable_target(tenant.tenant_id, update_campaign.id)
    end
  end

  describe "subscribe_to_operation_updates/1" do
    test "makes the process receive OTA Operation updates", %{tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(tenant: tenant)

      Core.subscribe_to_operation_updates!(ota_operation.id)

      # Generate a publish on the PubSub
      OSManagement.update_ota_operation_status!(ota_operation, "Acknowledged")

      assert_receive %Phoenix.Socket.Broadcast{
        event: "update_status",
        payload: %Ash.Notifier.Notification{
          data: %OTAOperation{status: :acknowledged}
        }
      }
    end
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
        assert Core.temporary_error?(%APIError{status: status, response: "Error"}) == true
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

  describe "ota_operation_acknowledged?/1" do
    test "returns true for OTA Operation with status acknowledged", %{tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(status: :acknowledged, tenant: tenant)

      assert Core.ota_operation_acknowledged?(ota_operation) == true
    end

    test "returns false for OTA Operation with other status", %{tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(status: :downloading, tenant: tenant)

      assert Core.ota_operation_acknowledged?(ota_operation) == false
    end
  end

  describe "ota_operation_successful?/1" do
    test "returns true for OTA Operation with status success", %{tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(status: :success, tenant: tenant)

      assert Core.ota_operation_successful?(ota_operation) == true
    end

    test "returns false for OTA Operation with other status", %{tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(status: :rebooting, tenant: tenant)

      assert Core.ota_operation_successful?(ota_operation) == false
    end
  end

  describe "ota_operation_failed?/1" do
    test "returns true for OTA Operation with status failure", %{tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(status: :failure, tenant: tenant)

      assert Core.ota_operation_failed?(ota_operation) == true
    end

    test "returns false for OTA Operation with other status", %{tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(status: :deploying, tenant: tenant)

      assert Core.ota_operation_failed?(ota_operation) == false
    end
  end

  describe "failure_threshold_exceeded?/3" do
    test "returns true when exceeding max_failure_percentage" do
      rollout = push_rollout_fixture(max_failure_percentage: 10)
      target_count = 100
      failed_count = 11

      assert Core.failure_threshold_exceeded?(target_count, failed_count, rollout) == true
    end

    test "returns false when not exceeding max_failure_percentage" do
      rollout = push_rollout_fixture(max_failure_percentage: 10)
      target_count = 100
      failed_count = 9

      assert Core.failure_threshold_exceeded?(target_count, failed_count, rollout) == false
    end

    test "returns false if the error percentage is exactly max_failure_percentage" do
      rollout = push_rollout_fixture(max_failure_percentage: 10)
      target_count = 100
      failed_count = 10

      assert Core.failure_threshold_exceeded?(target_count, failed_count, rollout) == false
    end
  end

  test "get_target_count/2", %{tenant: tenant} do
    update_campaign = update_campaign_with_targets_fixture(42, tenant: tenant)

    assert Core.get_target_count(tenant.tenant_id, update_campaign.id) == 42
  end

  test "get_failed_target_count/2", %{tenant: tenant} do
    update_campaign =
      10 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

    # Call start_update/2 to mark targets as in_progress
    update_campaign.update_targets
    |> Enum.take(7)
    |> Enum.each(&Core.mark_target_as_failed!/1)

    assert Core.get_failed_target_count(tenant.tenant_id, update_campaign.id) == 7
  end

  test "get_in_progress_target_count/2", %{tenant: tenant} do
    update_campaign =
      24 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

    # Call start_update/2 to mark targets as in_progress
    update_campaign.update_targets
    |> Enum.take(11)
    |> Ash.load!(Core.default_preloads_for_target())
    |> Enum.each(&Core.start_target_update(&1, update_campaign.base_image))

    assert Core.get_in_progress_target_count(tenant.tenant_id, update_campaign.id) == 11
  end

  describe "has_idle_targets?/2" do
    test "returns true for campaigns with a least one idle target", %{tenant: tenant} do
      update_campaign =
        5 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      update_campaign.update_targets
      |> Enum.take(4)
      |> Enum.each(&Core.mark_target_as_successful!/1)

      assert Core.has_idle_targets?(tenant.tenant_id, update_campaign.id) == true
    end

    test "returns false if all targets are in_progress", %{tenant: tenant} do
      update_campaign =
        3 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      # Call start_update/2 to mark targets as in_progress
      update_campaign.update_targets
      |> Ash.load!(Core.default_preloads_for_target())
      |> Enum.each(&Core.start_target_update(&1, update_campaign.base_image))

      assert Core.has_idle_targets?(tenant.tenant_id, update_campaign.id) == false
    end

    test "returns false if all targets are successful", %{tenant: tenant} do
      update_campaign =
        3 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      Enum.each(update_campaign.update_targets, &Core.mark_target_as_successful!/1)

      assert Core.has_idle_targets?(tenant.tenant_id, update_campaign.id) == false
    end

    test "returns false if all targets are failed", %{tenant: tenant} do
      update_campaign =
        3 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      Enum.each(update_campaign.update_targets, &Core.mark_target_as_failed!/1)

      assert Core.has_idle_targets?(tenant.tenant_id, update_campaign.id) == false
    end

    test "returns false if campaign has no targets", %{tenant: tenant} do
      update_campaign =
        [tenant: tenant] |> update_campaign_fixture() |> Ash.load!(:update_targets)

      assert update_campaign.update_targets == []
      assert Core.has_idle_targets?(tenant.tenant_id, update_campaign.id) == false
    end
  end

  test "mark_campaign_in_progress!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    assert %UpdateCampaign{status: :in_progress, start_timestamp: ^now} =
             3
             |> update_campaign_with_targets_fixture(tenant: tenant)
             |> Core.mark_campaign_in_progress!(now)
  end

  test "mark_campaign_as_failed!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    assert %UpdateCampaign{status: :finished, outcome: :failure, completion_timestamp: ^now} =
             3
             |> update_campaign_with_targets_fixture(tenant: tenant)
             |> Core.mark_campaign_as_failed!(now)
  end

  test "mark_campaign_as_successful!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    assert %UpdateCampaign{status: :finished, outcome: :success, completion_timestamp: ^now} =
             3
             |> update_campaign_with_targets_fixture(tenant: tenant)
             |> Core.mark_campaign_as_successful!(now)
  end

  describe "list_in_progress_targets/1" do
    test "returns empty list if no target has pending ota operations", %{tenant: tenant} do
      update_campaign =
        5 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      assert [] ==
               Core.list_in_progress_targets(tenant.tenant_id, update_campaign.id)
    end

    test "returns target if it has a pending OTA Operation", %{tenant: tenant} do
      update_campaign =
        5 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      assert {:ok, target} =
               update_campaign.update_targets
               |> hd()
               |> Ash.load!(Core.default_preloads_for_target())
               |> Core.start_target_update(update_campaign.base_image)

      assert [pending_ota_operation_target] =
               Core.list_in_progress_targets(tenant.tenant_id, update_campaign.id)

      assert pending_ota_operation_target.id == target.id
    end

    test "does not return target if its OTA Operation is in a different state", %{tenant: tenant} do
      update_campaign =
        5 |> update_campaign_with_targets_fixture(tenant: tenant) |> Ash.load!(:update_targets)

      assert {:ok, target} =
               update_campaign.update_targets
               |> hd()
               |> Ash.load!(Core.default_preloads_for_target())
               |> Core.start_target_update(update_campaign.base_image)

      assert {:ok, _ota_operation} =
               target.ota_operation_id
               |> OSManagement.fetch_ota_operation!(tenant: tenant)
               |> OSManagement.update_ota_operation_status(:acknowledged)

      assert [] ==
               Core.list_in_progress_targets(tenant.tenant_id, update_campaign.id)
    end
  end

  defp push_rollout_fixture(attrs \\ []) do
    attrs
    |> Enum.into(%{
      max_failure_percentage: 5.0,
      max_in_progress_updates: 10,
      force_downgrade: false,
      ota_request_retries: 0,
      ota_request_timeout_seconds: 60
    })
    |> then(&struct!(PushRollout, &1))
  end

  defp update_device_online_for_target!(target, online) do
    target = Ash.load!(target, :device)

    target.device
    |> Ash.Changeset.for_update(:from_device_status, %{online: online})
    |> Ash.update!()
  end

  defp set_target_retry_count!(target, count) do
    assert target.retry_count == 0
    Enum.reduce(1..count, target, fn _idx, target -> Core.increase_retry_count!(target) end)
  end
end
