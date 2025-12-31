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
  alias Edgehog.Campaigns.CampaignMechanism.Core, as: CampaignMechanismCore

  alias Edgehog.Campaigns.CampaignMechanism.Core.Edgehog.Campaigns.CampaignMechanism.FirmwareUpgrade,
    as: FirmwareUpgradeCore

  alias Edgehog.Campaigns.CampaignMechanism.FirmwareUpgrade
  alias Edgehog.Campaigns.Executor.Lazy.Core, as: LazyCore
  alias Edgehog.Error.AstarteAPIError
  alias Edgehog.OSManagement
  alias Edgehog.OSManagement.OTAOperation
  alias Phoenix.Socket.Broadcast

  setup do
    stub(OTARequestV1Mock, :update, fn _client, _device_id, _uuid, _url -> :ok end)
    %{tenant: tenant_fixture()}
  end

  describe "get_operation_id/2" do
    test "returns nil when target has no ota_operation", %{tenant: tenant} do
      target = target_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)

      mechanism = %FirmwareUpgrade{}

      assert CampaignMechanismCore.get_operation_id(mechanism, target) == nil
    end

    test "returns deployment_id when target has deployment", %{tenant: tenant} do
      base_image = base_image_fixture(tenant: tenant)

      target =
        [tenant: tenant, mechanism_type: :firmware_upgrade]
        |> target_fixture()
        |> Campaigns.start_fw_upgrade(base_image, tenant: tenant.tenant_id)
        |> Ash.load!(:ota_operation, tenant: tenant.tenant_id)

      mechanism = %FirmwareUpgrade{}

      assert CampaignMechanismCore.get_operation_id(mechanism, target) == target.ota_operation.id
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

      assert :ok = CampaignMechanismCore.retry_operation(mechanism, target)
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

      assert {:error, reason} = CampaignMechanismCore.retry_operation(mechanism, target)

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
      CampaignMechanismCore.mark_operation_as_timed_out!(
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
               CampaignMechanismCore.fetch_next_valid_target(
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

      [successful_target] = campaign.campaign_targets

      successful_target
      |> Ash.load!(default_preloads_for_target())
      |> LazyCore.mark_target_as_successful!()

      mechanism = %FirmwareUpgrade{}

      assert {:error, %Invalid{}} =
               CampaignMechanismCore.fetch_next_valid_target(
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

      [failed_target] = campaign.campaign_targets

      failed_target
      |> Ash.load!(default_preloads_for_target())
      |> LazyCore.mark_target_as_failed!()

      mechanism = %FirmwareUpgrade{}

      assert {:error, %Invalid{}} =
               CampaignMechanismCore.fetch_next_valid_target(
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
               CampaignMechanismCore.fetch_next_valid_target(
                 mechanism,
                 campaign.id,
                 tenant.tenant_id
               )

      target
      |> Ash.load!(default_preloads_for_target())
      |> update_device_online_for_target!(true)

      mechanism = %FirmwareUpgrade{}

      assert {:ok, online_target} =
               CampaignMechanismCore.fetch_next_valid_target(
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
               CampaignMechanismCore.fetch_next_valid_target(
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
               CampaignMechanismCore.fetch_next_valid_target(
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

      [successful_target, offline_target] = campaign.campaign_targets

      successful_target
      |> Ash.load!(default_preloads_for_target())
      |> LazyCore.mark_target_as_successful!()

      offline_target
      |> Ash.load!(default_preloads_for_target())
      |> update_device_online_for_target!(false)

      mechanism = %FirmwareUpgrade{}

      assert {:error, %Invalid{}} =
               CampaignMechanismCore.fetch_next_valid_target(
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

      CampaignMechanismCore.subscribe_to_operation_updates!(mechanism, ota_operation.id)

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
               CampaignMechanismCore.unsubscribe_to_operation_updates!(
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

      loaded_mechanism = CampaignMechanismCore.get_mechanism(mechanism, campaign)

      assert %FirmwareUpgrade{} = loaded_mechanism
      assert loaded_mechanism.base_image
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

  defp default_preloads_for_target do
    [
      ota_operation: [:status],
      device: [realm: [:cluster]]
    ]
  end
end
