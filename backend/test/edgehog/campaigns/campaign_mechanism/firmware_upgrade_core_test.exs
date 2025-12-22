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

defmodule Edgehog.Campaigns.CampaignMechanism.FirmwareUpgradeCoreTest do
  use Edgehog.DataCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.CampaignsFixtures
  import Edgehog.OSManagementFixtures
  import Edgehog.TenantsFixtures

  alias Ash.Error.Invalid
  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.BaseImage
  alias Edgehog.Astarte.Device.BaseImageMock
  alias Edgehog.Astarte.Device.OTARequestV1Mock
  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.CampaignMechanism.Core, as: MechanismCore
  alias Edgehog.Campaigns.CampaignMechanism.FirmwareUpgrade
  alias Edgehog.Campaigns.CampaignTarget
  alias Edgehog.Error.AstarteAPIError
  alias Edgehog.OSManagement
  alias Edgehog.OSManagement.OTAOperation
  alias MechanismCore.Edgehog.Campaigns.CampaignMechanism.FirmwareUpgrade, as: FirmwareUpgradeCore
  alias Phoenix.Socket.Broadcast

  setup do
    stub(OTARequestV1Mock, :update, fn _client, _device_id, _uuid, _url -> :ok end)
    %{tenant: tenant_fixture()}
  end

  describe "get_operation_id/2" do
    test "returns nil when target has no ota_operation", %{tenant: tenant} do
      target = target_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)

      mechanism = %FirmwareUpgrade{}

      assert MechanismCore.get_operation_id(mechanism, target) == nil
    end

    test "returns deployment_id when target has deployment", %{tenant: tenant} do
      base_image = base_image_fixture(tenant: tenant)

      target =
        [tenant: tenant, mechanism_type: :firmware_upgrade]
        |> target_fixture()
        |> Campaigns.start_fw_upgrade(base_image, tenant: tenant.tenant_id)
        |> Ash.load!(:ota_operation, tenant: tenant.tenant_id)

      mechanism = %FirmwareUpgrade{}

      assert MechanismCore.get_operation_id(mechanism, target) == target.ota_operation.id
    end
  end

  describe "retry_operation/2" do
    setup %{tenant: tenant} do
      target =
        [tenant: tenant, mechanism_type: :firmware_upgrade]
        |> in_progress_target_fixture()
        |> Ash.load!(default_preloads_for_target())

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

      mechanism = %FirmwareUpgrade{}

      assert :ok = MechanismCore.retry_operation(mechanism, target)
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

      mechanism = %FirmwareUpgrade{}

      assert {:error, reason} = MechanismCore.retry_operation(mechanism, target)

      assert %Invalid{
               errors: [
                 %AstarteAPIError{status: 500, response: "Internal server error"}
               ]
             } = reason
    end
  end

  describe "fetch_target_current_version/1" do
    setup %{tenant: tenant} do
      target =
        [tenant: tenant, mechanism_type: :firmware_upgrade]
        |> target_fixture()
        |> Ash.load!(default_preloads_for_target())

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

      assert {:ok, version} = FirmwareUpgradeCore.fetch_target_current_version(target)
      assert Version.compare(version, "4.3.1") == :eq
    end

    test "returns error if the Astarte API replies with an error", ctx do
      %{target: target} = ctx

      expect(BaseImageMock, :get, fn _client, _device_id ->
        {:error, %APIError{status: 500, response: "Internal server error"}}
      end)

      assert {:error, :missing_version} = FirmwareUpgradeCore.fetch_target_current_version(target)
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

      assert {:error, :invalid_version} = FirmwareUpgradeCore.fetch_target_current_version(target)
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

      assert {:error, :missing_version} = FirmwareUpgradeCore.fetch_target_current_version(target)
    end
  end

  describe "needs_update?/2" do
    test "returns true if the target has a different version from the base image", %{
      tenant: tenant
    } do
      base_image = base_image_fixture(version: "1.1.0", tenant: tenant)
      target_current_version = Version.parse!("1.0.0")

      assert FirmwareUpgradeCore.needs_update?(target_current_version, base_image) == true
    end

    test "returns true if the target has a different build segment from the base image", %{
      tenant: tenant
    } do
      base_image = base_image_fixture(version: "1.1.0+build1", tenant: tenant)
      target_current_version = Version.parse!("1.1.0+build0")

      assert FirmwareUpgradeCore.needs_update?(target_current_version, base_image) == true
    end

    test "returns false if the target has exactly the same version as the base image", %{
      tenant: tenant
    } do
      base_image = base_image_fixture(version: "1.3.4-beta.0+build1", tenant: tenant)
      target_current_version = Version.parse!(base_image.version)

      assert FirmwareUpgradeCore.needs_update?(target_current_version, base_image) == false
    end
  end

  describe "verify_compatibility/2" do
    test "returns error when trying to downgrade and force_downgrade: false", %{tenant: tenant} do
      base_image = base_image_fixture(version: "1.1.0", tenant: tenant)
      target_current_version = Version.parse!("1.2.0")
      mechanism = firmware_upgrade_mechanism_fixture(force_downgrade: false)

      assert FirmwareUpgradeCore.verify_compatibility(
               target_current_version,
               base_image,
               mechanism
             ) ==
               {:error, :downgrade_not_allowed}
    end

    test "returns error when passing same version with different build segment and force_downgrade: false",
         %{tenant: tenant} do
      base_image = base_image_fixture(version: "1.1.0+build0", tenant: tenant)
      target_current_version = Version.parse!("1.1.0+build1")
      mechanism = firmware_upgrade_mechanism_fixture(force_downgrade: false)

      assert FirmwareUpgradeCore.verify_compatibility(
               target_current_version,
               base_image,
               mechanism
             ) ==
               {:error, :ambiguous_version_ordering}
    end

    test "returns :ok when downgrading with force_downgrade: true", %{tenant: tenant} do
      base_image = base_image_fixture(version: "1.1.0", tenant: tenant)
      target_current_version = Version.parse!("1.2.0")
      mechanism = firmware_upgrade_mechanism_fixture(force_downgrade: true)

      assert FirmwareUpgradeCore.verify_compatibility(
               target_current_version,
               base_image,
               mechanism
             ) == :ok
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
      mechanism = firmware_upgrade_mechanism_fixture()

      assert FirmwareUpgradeCore.verify_compatibility(
               target_current_version,
               base_image,
               mechanism
             ) ==
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
      mechanism = firmware_upgrade_mechanism_fixture()

      assert FirmwareUpgradeCore.verify_compatibility(
               target_current_version,
               base_image,
               mechanism
             ) == :ok
    end
  end

  test "mark_operation_as_timed_out!/2", %{tenant: tenant} do
    base_image = base_image_fixture(tenant: tenant)

    {:ok, target} =
      [tenant: tenant, mechanism_type: :firmware_upgrade]
      |> target_fixture()
      |> Ash.load!(ota_operation: [:status])
      |> FirmwareUpgradeCore.start_target_update(base_image)

    mechanism = firmware_upgrade_mechanism_fixture()

    ota_operation =
      MechanismCore.mark_operation_as_timed_out!(
        mechanism,
        target.ota_operation_id,
        tenant.tenant_id
      )

    assert ota_operation.status == :failure
    assert ota_operation.status_code == :request_timeout
  end

  describe "fetch_next_valid_target/3" do
    test "does not return :pending targets", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [firmware_upgrade: [:base_image]])

      [pending_target] = campaign.campaign_targets
      mechanism = campaign.campaign_mechanism.value

      pending_target
      |> Ash.load!(default_preloads_for_target())
      |> FirmwareUpgradeCore.start_target_update(mechanism.base_image)

      assert {:error, %Invalid{}} =
               MechanismCore.fetch_next_valid_target(
                 mechanism,
                 campaign.id,
                 tenant.tenant_id
               )
    end

    test "does not return :successful targets", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      mechanism = %FirmwareUpgrade{}

      [successful_target] = campaign.campaign_targets

      target = Ash.load!(successful_target, default_preloads_for_target())

      _ = MechanismCore.mark_target_as_successful!(mechanism, target)

      assert {:error, %Invalid{}} =
               MechanismCore.fetch_next_valid_target(
                 mechanism,
                 campaign.id,
                 tenant.tenant_id
               )
    end

    test "does not return :failed targets", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      mechanism = %FirmwareUpgrade{}

      [failed_target] = campaign.campaign_targets

      target = Ash.load!(failed_target, default_preloads_for_target())

      _ = MechanismCore.mark_target_as_failed!(mechanism, target)

      assert {:error, %Invalid{}} =
               MechanismCore.fetch_next_valid_target(
                 mechanism,
                 campaign.id,
                 tenant.tenant_id
               )
    end

    test "only returns online targets", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      [target] = campaign.campaign_targets

      target
      |> Ash.load!(default_preloads_for_target())
      |> update_device_online_for_target!(false)

      mechanism = %FirmwareUpgrade{}

      assert {:error, %Invalid{}} =
               MechanismCore.fetch_next_valid_target(
                 mechanism,
                 campaign.id,
                 tenant.tenant_id
               )

      target
      |> Ash.load!(default_preloads_for_target())
      |> update_device_online_for_target!(true)

      mechanism = %FirmwareUpgrade{}

      assert {:ok, online_target} =
               MechanismCore.fetch_next_valid_target(
                 mechanism,
                 campaign.id,
                 tenant.tenant_id
               )

      assert target.id == online_target.id
    end

    test "returns targets without any attempts first", %{tenant: tenant} do
      campaign =
        2
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      [target_with_attempt, target_with_no_attempt] = campaign.campaign_targets

      Campaigns.update_target_latest_attempt!(target_with_attempt, DateTime.utc_now())
      mechanism = %FirmwareUpgrade{}

      assert {:ok, target} =
               MechanismCore.fetch_next_valid_target(
                 mechanism,
                 campaign.id,
                 tenant.tenant_id
               )

      assert target.id == target_with_no_attempt.id
    end

    test "returns targets with oldest attempt first", %{tenant: tenant} do
      campaign =
        2
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      [target_with_old_attempt, target_with_recent_attempt] = campaign.campaign_targets

      recent_attempt_timestamp = DateTime.utc_now()

      Campaigns.update_target_latest_attempt!(
        target_with_recent_attempt,
        recent_attempt_timestamp
      )

      old_attempt_timestamp = DateTime.add(recent_attempt_timestamp, -10, :hour)
      Campaigns.update_target_latest_attempt!(target_with_old_attempt, old_attempt_timestamp)
      mechanism = %FirmwareUpgrade{}

      assert {:ok, target} =
               MechanismCore.fetch_next_valid_target(
                 mechanism,
                 campaign.id,
                 tenant.tenant_id
               )

      assert target.id == target_with_old_attempt.id
    end

    test "returns {:error, :no_updatable_targets} with no updatable targets", %{tenant: tenant} do
      campaign =
        2
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      mechanism = %FirmwareUpgrade{}

      [successful_target, offline_target] = campaign.campaign_targets

      target = Ash.load!(successful_target, default_preloads_for_target())

      _ = MechanismCore.mark_target_as_successful!(mechanism, target)

      offline_target
      |> Ash.load!(default_preloads_for_target())
      |> update_device_online_for_target!(false)

      assert {:error, %Invalid{}} =
               MechanismCore.fetch_next_valid_target(
                 mechanism,
                 campaign.id,
                 tenant.tenant_id
               )
    end
  end

  describe "subscribe_to_operation_updates/1" do
    test "makes the process receive OTA Operation updates", %{tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(tenant: tenant)
      mechanism = %FirmwareUpgrade{}

      MechanismCore.subscribe_to_operation_updates!(mechanism, ota_operation.id)

      # Generate a publish on the PubSub
      OSManagement.update_ota_operation_status!(ota_operation, "Acknowledged")
      topic = "ota_operations:#{ota_operation.id}"
      ota_operation_id = ota_operation.id

      assert_receive %Broadcast{
        topic: ^topic,
        event: "update_status",
        payload: %Ash.Notifier.Notification{
          data: %OTAOperation{id: ^ota_operation_id, status: :acknowledged}
        }
      }

      # Then unsubscribe
      assert :ok =
               MechanismCore.unsubscribe_to_operation_updates!(
                 mechanism,
                 ota_operation.id
               )

      # Trigger an update
      OSManagement.update_ota_operation_status!(ota_operation, "Acknowledged")

      # Should not receive any notification
      refute_receive %Broadcast{topic: ^topic}
    end
  end

  describe "get_mechanism/2" do
    test "loads and returns the full mechanism configuration", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)

      mechanism = %FirmwareUpgrade{}

      loaded_mechanism = MechanismCore.get_mechanism(mechanism, campaign)

      assert %FirmwareUpgrade{} = loaded_mechanism
      assert loaded_mechanism.base_image
    end
  end

  describe "get_campaign!/2" do
    test "returns the the update campaign if it is present", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
      mechanism = campaign.campaign_mechanism.value

      assert %Campaign{id: id, tenant_id: tenant_id, campaign_mechanism: campaign_mechanism} =
               MechanismCore.get_campaign!(mechanism, tenant.tenant_id, campaign.id)

      assert campaign.id == id
      assert campaign.tenant_id == tenant_id
      assert campaign.campaign_mechanism == campaign_mechanism
    end

    test "raises for non-existing update campaign", %{tenant: tenant} do
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
      campaign_mechanism = firmware_upgrade_mechanism_fixture()

      assert_raise MatchError, fn ->
        MechanismCore.pending_request_timeout_ms(campaign_mechanism, ctx.target)
      end
    end

    test "returns the remaining milliseconds if the timeout is not expired", ctx do
      latest_attempt = DateTime.utc_now()

      target =
        Campaigns.update_target_latest_attempt!(ctx.target, latest_attempt)

      campaign_mechanism = firmware_upgrade_mechanism_fixture(request_timeout_seconds: 5)
      time_of_check = DateTime.add(latest_attempt, 3, :second)

      assert MechanismCore.pending_request_timeout_ms(campaign_mechanism, target, time_of_check) ==
               2000
    end

    test "returns 0 if the timeout is already expired", ctx do
      latest_attempt = DateTime.utc_now()

      target =
        Campaigns.update_target_latest_attempt!(ctx.target, latest_attempt)

      campaign_mechanism = firmware_upgrade_mechanism_fixture(request_timeout_seconds: 5)
      time_of_check = DateTime.add(latest_attempt, 10, :second)

      assert MechanismCore.pending_request_timeout_ms(campaign_mechanism, target, time_of_check) ==
               0
    end
  end

  test "increase_retry_count!/1", %{tenant: tenant} do
    target = target_fixture(tenant: tenant)
    new_target = MechanismCore.increase_retry_count!(%FirmwareUpgrade{}, target)

    assert new_target.retry_count == target.retry_count + 1
  end

  describe "can_retry?/2" do
    setup %{tenant: tenant} do
      target = target_fixture(tenant: tenant)

      %{target: target}
    end

    test "returns true if the target still has retries left", ctx do
      target = set_target_retry_count!(ctx.target, 4)
      campaign_mechanism = firmware_upgrade_mechanism_fixture(request_retries: 5)

      assert MechanismCore.can_retry?(campaign_mechanism, target) == true
    end

    test "returns false if the target has no retries left", ctx do
      target = set_target_retry_count!(ctx.target, 5)
      campaign_mechanism = firmware_upgrade_mechanism_fixture(request_retries: 5)

      assert MechanismCore.can_retry?(campaign_mechanism, target) == false
    end
  end

  describe "get_target!/2" do
    test "returns target if existing", %{tenant: tenant} do
      %{id: target_id} = target_fixture(tenant: tenant)

      assert %CampaignTarget{id: ^target_id} =
               MechanismCore.get_target!(%FirmwareUpgrade{}, tenant.tenant_id, target_id)
    end

    test "raises with non-existing target", %{tenant: tenant} do
      assert_raise Invalid, fn ->
        MechanismCore.get_target!(%FirmwareUpgrade{}, tenant.tenant_id, 1_234_567)
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
               MechanismCore.get_target_for_operation!(
                 %FirmwareUpgrade{},
                 tenant.tenant_id,
                 target.campaign.id,
                 target.device_id
               )
    end

    test "raises with non-existing linked target", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)

      assert_raise Invalid, fn ->
        MechanismCore.get_target_for_operation!(
          %FirmwareUpgrade{},
          tenant.tenant_id,
          campaign.id,
          "non_existing_device_id"
        )
      end
    end
  end

  describe "available_slots/2" do
    test "returns the number of available update slots given the current in progress count" do
      mechanism = firmware_upgrade_mechanism_fixture(max_in_progress_operations: 10)
      in_progress = 7
      assert MechanismCore.available_slots(mechanism, in_progress) == 3
    end

    test "returns 0 if there are more in progress updates than allowed" do
      mechanism = firmware_upgrade_mechanism_fixture(max_in_progress_operations: 5)
      in_progress = 7
      assert MechanismCore.available_slots(mechanism, in_progress) == 0
    end
  end

  test "mark_target_as_failed!/2", %{tenant: tenant} do
    completion_timestamp = ~U[2023-06-08 13:59:52.928623Z]

    target = target_fixture(tenant: tenant)

    target =
      MechanismCore.mark_target_as_failed!(%FirmwareUpgrade{}, target, completion_timestamp)

    assert target.status == :failed
    assert target.completion_timestamp == completion_timestamp
  end

  test "mark_target_as_successful!/2", %{tenant: tenant} do
    completion_timestamp = ~U[2023-06-08 13:59:52.928623Z]

    target = target_fixture(tenant: tenant)

    target =
      MechanismCore.mark_target_as_successful!(%FirmwareUpgrade{}, target, completion_timestamp)

    assert target.status == :successful
    assert target.completion_timestamp == completion_timestamp
  end

  describe "error_message/3" do
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
        msg = MechanismCore.error_message(%FirmwareUpgrade{}, error, ctx.device_id)
        assert msg =~ ctx.device_id
        refute msg =~ "failed with unknown error"
      end
    end

    test "returns generic error message for unknown error", ctx do
      msg = MechanismCore.error_message(%FirmwareUpgrade{}, :a_new_kind_of_error, ctx.device_id)
      assert msg =~ ctx.device_id
      assert msg =~ "failed with unknown error"
    end
  end

  describe "temporary_error?/1" do
    test "returns true for connection refused" do
      assert MechanismCore.temporary_error?(%FirmwareUpgrade{}, "connection refused") == true
    end

    test "returns true for API errors with status code in 500..599" do
      for status <- 500..599 do
        assert MechanismCore.temporary_error?(%FirmwareUpgrade{}, %APIError{
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
        assert MechanismCore.temporary_error?(%FirmwareUpgrade{}, error) == false
      end
    end

    test "returns false for unknown errors" do
      assert MechanismCore.temporary_error?(%FirmwareUpgrade{}, :a_new_kind_of_error) == false
    end
  end

  test "get_target_count/2", %{tenant: tenant} do
    campaign =
      campaign_with_targets_fixture(42, tenant: tenant, mechanism_type: :firmware_upgrade)

    assert MechanismCore.get_target_count(%FirmwareUpgrade{}, tenant.tenant_id, campaign.id) == 42
  end

  test "get_failed_target_count/2", %{tenant: tenant} do
    campaign =
      10
      |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
      |> Ash.load!(:campaign_targets)

    campaign.campaign_targets
    |> Enum.take(7)
    |> Enum.each(fn target ->
      MechanismCore.mark_target_as_failed!(%FirmwareUpgrade{}, target)
    end)

    assert MechanismCore.get_failed_target_count(
             %FirmwareUpgrade{},
             tenant.tenant_id,
             campaign.id
           ) == 7
  end

  test "get_in_progress_target_count/2", %{tenant: tenant} do
    campaign =
      24
      |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
      |> Ash.load!(campaign_targets: [], campaign_mechanism: [firmware_upgrade: [:base_image]])

    # Call start_update/2 to mark targets as in_progress
    campaign.campaign_targets
    |> Enum.take(11)
    |> Enum.each(
      &FirmwareUpgradeCore.start_target_update(
        &1,
        campaign.campaign_mechanism.value.base_image
      )
    )

    assert MechanismCore.get_in_progress_target_count(
             %FirmwareUpgrade{},
             tenant.tenant_id,
             campaign.id
           ) == 11
  end

  describe "has_idle_targets?/2" do
    test "returns true for campaigns with a least one idle target", %{tenant: tenant} do
      campaign =
        5
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      campaign.campaign_targets
      |> Enum.take(4)
      |> Enum.each(fn target ->
        MechanismCore.mark_target_as_successful!(%FirmwareUpgrade{}, target)
      end)

      assert MechanismCore.has_idle_targets?(%FirmwareUpgrade{}, tenant.tenant_id, campaign.id) ==
               true
    end

    test "returns false if all targets are in_progress", %{tenant: tenant} do
      campaign =
        3
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [firmware_upgrade: [:base_image]])

      # Call start_update/2 to mark targets as in_progress
      Enum.each(
        campaign.campaign_targets,
        &FirmwareUpgradeCore.start_target_update(
          &1,
          campaign.campaign_mechanism.value.base_image
        )
      )

      assert MechanismCore.has_idle_targets?(%FirmwareUpgrade{}, tenant.tenant_id, campaign.id) ==
               false
    end

    test "returns false if all targets are successful", %{tenant: tenant} do
      campaign =
        3
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      Enum.each(campaign.campaign_targets, fn target ->
        MechanismCore.mark_target_as_successful!(%FirmwareUpgrade{}, target)
      end)

      assert MechanismCore.has_idle_targets?(%FirmwareUpgrade{}, tenant.tenant_id, campaign.id) ==
               false
    end

    test "returns false if all targets are failed", %{tenant: tenant} do
      campaign =
        3
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      Enum.each(campaign.campaign_targets, fn target ->
        MechanismCore.mark_target_as_failed!(%FirmwareUpgrade{}, target)
      end)

      assert MechanismCore.has_idle_targets?(%FirmwareUpgrade{}, tenant.tenant_id, campaign.id) ==
               false
    end

    test "returns false if campaign has no targets", %{tenant: tenant} do
      campaign =
        [tenant: tenant, mechanism_type: :firmware_upgrade]
        |> campaign_fixture()
        |> Ash.load!(:campaign_targets)

      assert campaign.campaign_targets == []

      assert MechanismCore.has_idle_targets?(%FirmwareUpgrade{}, tenant.tenant_id, campaign.id) ==
               false
    end
  end

  test "mark_campaign_in_progress!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    campaign = campaign_with_targets_fixture(3, tenant: tenant, mechanism_type: :firmware_upgrade)

    assert %Campaign{status: :in_progress, start_timestamp: ^now} =
             MechanismCore.mark_campaign_in_progress!(%FirmwareUpgrade{}, campaign, now)
  end

  test "mark_campaign_as_failed!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    campaign = campaign_with_targets_fixture(3, tenant: tenant, mechanism_type: :firmware_upgrade)

    assert %Campaign{status: :finished, outcome: :failure, completion_timestamp: ^now} =
             MechanismCore.mark_campaign_as_failed!(%FirmwareUpgrade{}, campaign, now)
  end

  test "mark_campaign_as_successful!/1", %{tenant: tenant} do
    now = DateTime.utc_now()

    campaign = campaign_with_targets_fixture(3, tenant: tenant, mechanism_type: :firmware_upgrade)

    assert %Campaign{status: :finished, outcome: :success, completion_timestamp: ^now} =
             MechanismCore.mark_campaign_as_successful!(%FirmwareUpgrade{}, campaign, now)
  end

  describe "list_in_progress_targets/1" do
    test "returns empty list if no target has pending ota operations", %{tenant: tenant} do
      campaign =
        5
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(:campaign_targets)

      assert [] ==
               MechanismCore.list_in_progress_targets(
                 %FirmwareUpgrade{},
                 tenant.tenant_id,
                 campaign.id
               )
    end

    test "returns target if it has a pending OTA Operation", %{tenant: tenant} do
      campaign =
        5
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [firmware_upgrade: [:base_image]])

      assert {:ok, target} =
               campaign.campaign_targets
               |> hd()
               |> FirmwareUpgradeCore.start_target_update(campaign.campaign_mechanism.value.base_image)

      assert [pending_ota_operation_target] =
               MechanismCore.list_in_progress_targets(
                 %FirmwareUpgrade{},
                 tenant.tenant_id,
                 campaign.id
               )

      assert pending_ota_operation_target.id == target.id
    end

    test "does not return target if its OTA Operation is in a different state", %{tenant: tenant} do
      campaign =
        5
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [firmware_upgrade: [:base_image]])

      assert {:ok, target} =
               campaign.campaign_targets
               |> hd()
               |> Ash.load!(default_preloads_for_target())
               |> FirmwareUpgradeCore.start_target_update(campaign.campaign_mechanism.value.base_image)

      assert {:ok, _ota_operation} =
               target.ota_operation_id
               |> OSManagement.fetch_ota_operation!(tenant: tenant)
               |> OSManagement.update_ota_operation_status(:acknowledged)

      assert [] ==
               MechanismCore.list_in_progress_targets(
                 %FirmwareUpgrade{},
                 tenant.tenant_id,
                 campaign.id
               )
    end
  end

  defp firmware_upgrade_mechanism_fixture(attrs \\ []) do
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

  defp update_device_online_for_target!(target, online) do
    target = Ash.load!(target, :device)

    target.device
    |> Ash.Changeset.for_update(:from_device_status, %{online: online})
    |> Ash.update!()
  end

  defp set_target_retry_count!(target, count) do
    assert target.retry_count == 0

    Enum.reduce(1..count, target, fn _idx, target ->
      MechanismCore.increase_retry_count!(%FirmwareUpgrade{}, target)
    end)
  end

  defp default_preloads_for_target do
    [
      ota_operation: [:status],
      device: [realm: [:cluster]]
    ]
  end
end
