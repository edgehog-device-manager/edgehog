#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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
  use Edgehog.AstarteMockCase
  use Edgehog.DataCase

  alias Edgehog.UpdateCampaigns.PushRollout
  alias Edgehog.UpdateCampaigns.PushRollout.Core
  alias Edgehog.UpdateCampaigns.UpdateCampaign

  alias Astarte.Client.APIError
  alias Edgehog.Astarte
  alias Edgehog.AstarteFixtures
  alias Edgehog.DevicesFixtures
  alias Edgehog.OSManagementFixtures
  import Edgehog.UpdateCampaignsFixtures

  describe "get_update_campaign!/1" do
    test "returns the the update campaign if it is present" do
      update_campaign = update_campaign_fixture()

      assert %UpdateCampaign{id: id, rollout_mechanism: rollout_mechanism} =
               Core.get_update_campaign!(update_campaign.id)

      assert update_campaign.id == id
      assert update_campaign.rollout_mechanism == rollout_mechanism
    end

    test "raises for non-existing update campaign" do
      assert_raise Ecto.NoResultsError, fn -> Core.get_update_campaign!(12_345) end
    end
  end

  describe "get_update_campaign_base_image!/1" do
    alias Edgehog.BaseImages

    test "returns the base image if the update campaign is present" do
      update_campaign = update_campaign_fixture()

      assert update_campaign.base_image ==
               Core.get_update_campaign_base_image!(update_campaign.id)
               |> BaseImages.preload_defaults_for_base_image()
    end

    test "raises for non-existing update campaign" do
      assert_raise Ecto.NoResultsError, fn -> Core.get_update_campaign_base_image!(12_345) end
    end
  end

  test "update_target_latest_attempt!/2" do
    latest_attempt = ~U[2023-06-06 16:19:44.404358Z]

    target =
      target_fixture()
      |> Core.update_target_latest_attempt!(latest_attempt)

    assert target.latest_attempt == latest_attempt
  end

  describe "pending_ota_request_timeout_ms/3" do
    setup do
      target = target_fixture()

      %{target: target}
    end

    test "raises if latest_attempt is not set", ctx do
      rollout_mechanism = push_rollout_fixture()

      assert_raise FunctionClauseError, fn ->
        Core.pending_ota_request_timeout_ms(ctx.target, rollout_mechanism)
      end
    end

    test "returns the remaining milliseconds if the timeout is not expired", ctx do
      latest_attempt = DateTime.utc_now()

      target =
        ctx.target
        |> Core.update_target_latest_attempt!(latest_attempt)

      rollout_mechanism = push_rollout_fixture(ota_request_timeout_seconds: 5)
      time_of_check = DateTime.add(latest_attempt, 3, :second)

      assert Core.pending_ota_request_timeout_ms(target, rollout_mechanism, time_of_check) == 2000
    end

    test "returns 0 if the timeout is already expired", ctx do
      latest_attempt = DateTime.utc_now()

      target =
        ctx.target
        |> Core.update_target_latest_attempt!(latest_attempt)

      rollout_mechanism = push_rollout_fixture(ota_request_timeout_seconds: 5)
      time_of_check = DateTime.add(latest_attempt, 10, :second)

      assert Core.pending_ota_request_timeout_ms(target, rollout_mechanism, time_of_check) == 0
    end
  end

  test "increase_retry_count!/1" do
    target = target_fixture()
    new_target = Core.increase_retry_count!(target)

    assert new_target.retry_count == target.retry_count + 1
  end

  describe "can_retry?/2" do
    setup do
      target = target_fixture()

      %{target: target}
    end

    test "returns true if the target still has retries left", ctx do
      target = set_target_retry_count!(ctx.target, 4)
      rollout_mechanism = push_rollout_fixture(ota_request_retries: 5)

      assert Core.can_retry?(target, rollout_mechanism) == true
    end

    test "returns false if the target has no retries left", ctx do
      target = set_target_retry_count!(ctx.target, 6)
      rollout_mechanism = push_rollout_fixture(ota_request_retries: 5)

      assert Core.can_retry?(target, rollout_mechanism) == false
    end
  end

  describe "retry_target_update/2" do
    import Edgehog.BaseImagesFixtures

    setup do
      target =
        target_fixture()
        |> Core.preload_defaults_for_target()

      base_image = base_image_fixture()

      %{target: target, base_image: base_image}
    end

    test "succeeds if Astarte API replies with a success", ctx do
      %{
        base_image: base_image,
        target: target
      } = ctx

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _client, device_id, _uuid, url ->
        assert device_id == target.device.device_id
        assert url == base_image.url
        :ok
      end)

      assert :ok = Core.retry_target_update(target, base_image)
    end

    test "fails if Astarte API replies with a failure", ctx do
      %{
        base_image: base_image,
        target: target
      } = ctx

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _client, device_id, _uuid, url ->
        assert device_id == target.device.device_id
        assert url == base_image.url
        {:error, %APIError{status: 500, response: "Internal server error"}}
      end)

      assert {:error, %APIError{status: 500}} = Core.retry_target_update(target, base_image)
    end
  end

  describe "get_target!/1" do
    alias Edgehog.UpdateCampaigns.Target

    test "returns target if existing" do
      %{id: target_id} = target_fixture()

      assert %Target{id: ^target_id} = Core.get_target!(target_id)
    end

    test "raises with non-existing target" do
      assert_raise Ecto.NoResultsError, fn -> Core.get_target!(1_234_567) end
    end
  end

  describe "get_target_for_update_operation!/1" do
    alias Edgehog.UpdateCampaigns.Target
    import Edgehog.BaseImagesFixtures

    setup do
      target =
        target_fixture()
        |> Core.preload_defaults_for_target()

      base_image = base_image_fixture()

      %{target: target, base_image: base_image}
    end

    test "returns target with an OTA Operation if existing", ctx do
      %{
        base_image: base_image,
        target: target
      } = ctx

      {:ok, target} = Core.start_target_update(target, base_image)
      target_id = target.id

      assert %Target{id: ^target_id} =
               Core.get_target_for_ota_operation!(target.ota_operation_id)
    end

    test "raises with non-existing linked target" do
      assert_raise Ecto.NoResultsError, fn ->
        Core.get_target_for_ota_operation!(Ecto.UUID.generate())
      end
    end
  end

  describe "start_target_update/2" do
    import Edgehog.BaseImagesFixtures

    setup do
      target =
        target_fixture()
        |> Core.preload_defaults_for_target()

      base_image = base_image_fixture()

      %{target: target, base_image: base_image}
    end

    test "succeeds if Astarte API replies with a success", ctx do
      %{
        base_image: base_image,
        target: target
      } = ctx

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _client, device_id, _uuid, url ->
        assert device_id == target.device.device_id
        assert url == base_image.url
        :ok
      end)

      assert {:ok, target} = Core.start_target_update(target, base_image)
      assert target.status == :in_progress
      assert target.ota_operation_id != nil
    end

    test "fails if Astarte API replies with a failure", ctx do
      %{
        base_image: base_image,
        target: target
      } = ctx

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _client, device_id, _uuid, url ->
        assert device_id == target.device.device_id
        assert url == base_image.url
        {:error, %APIError{status: 500, response: "Internal server error"}}
      end)

      assert {:error, %APIError{status: 500}} = Core.start_target_update(target, base_image)

      assert target.status == :idle
    end
  end

  describe "available_update_slots/2" do
    test "returns the number of available update slots given the current in progress count" do
      rollout = push_rollout_fixture(max_in_progress_updates: 10)
      in_progress = 7
      assert Core.available_update_slots(rollout, in_progress) == 3
    end

    test "returns 0 if there are more in progress updates than allowed" do
      rollout = push_rollout_fixture(max_in_progress_updates: 5)
      in_progress = 7
      assert Core.available_update_slots(rollout, in_progress) == 0
    end
  end

  describe "fetch_target_current_version/1" do
    setup do
      target =
        target_fixture()
        |> Core.preload_defaults_for_target()

      %{target: target}
    end

    test "returns the version if Astarte API replies with a success", ctx do
      %{target: target} = ctx

      Edgehog.Astarte.Device.BaseImageMock
      |> expect(:get, fn _client, device_id ->
        assert device_id == target.device.device_id

        base_image = %Edgehog.Astarte.Device.BaseImage{
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

      Edgehog.Astarte.Device.BaseImageMock
      |> expect(:get, fn _client, _device_id ->
        {:error, %APIError{status: 500, response: "Internal server error"}}
      end)

      assert {:error, %APIError{status: 500}} = Core.fetch_target_current_version(target)
    end

    test "returns error if the returned version is invalid", ctx do
      %{target: target} = ctx

      Edgehog.Astarte.Device.BaseImageMock
      |> expect(:get, fn _client, _device_id ->
        base_image = %Edgehog.Astarte.Device.BaseImage{
          name: "esp-idf",
          version: "3.not-a-valid-semver",
          build_id: "2022-01-01 12:00:00",
          fingerprint: "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3"
        }

        {:ok, base_image}
      end)

      assert {:error, :invalid_version} = Core.fetch_target_current_version(target)
    end
  end

  describe "needs_update?/2" do
    import Edgehog.BaseImagesFixtures

    test "returns true if the target has a different version from the base image" do
      base_image = base_image_fixture(version: "1.1.0")
      target_current_version = Version.parse!("1.0.0")

      assert Core.needs_update?(target_current_version, base_image) == true
    end

    test "returns true if the target has a different build segment from the base image" do
      base_image = base_image_fixture(version: "1.1.0+build1")
      target_current_version = Version.parse!("1.1.0+build0")

      assert Core.needs_update?(target_current_version, base_image) == true
    end

    test "returns false if the target has exactly the same version as the base image" do
      base_image = base_image_fixture(version: "1.3.4-beta.0+build1")
      target_current_version = Version.parse!(base_image.version)

      assert Core.needs_update?(target_current_version, base_image) == false
    end
  end

  describe "verify_compatibility/2" do
    import Edgehog.BaseImagesFixtures

    test "returns error when trying to downgrade and force_downgrade: false" do
      base_image = base_image_fixture(version: "1.1.0")
      target_current_version = Version.parse!("1.2.0")
      rollout = push_rollout_fixture(force_downgrade: false)

      assert Core.verify_compatibility(target_current_version, base_image, rollout) ==
               {:error, :downgrade_not_allowed}
    end

    test "returns error when passing same version with different build segment and force_downgrade: false" do
      base_image = base_image_fixture(version: "1.1.0+build0")
      target_current_version = Version.parse!("1.1.0+build1")
      rollout = push_rollout_fixture(force_downgrade: false)

      assert Core.verify_compatibility(target_current_version, base_image, rollout) ==
               {:error, :ambiguous_version_ordering}
    end

    test "returns :ok when downgrading with force_downgrade: true" do
      base_image = base_image_fixture(version: "1.1.0")
      target_current_version = Version.parse!("1.2.0")
      rollout = push_rollout_fixture(force_downgrade: true)

      assert Core.verify_compatibility(target_current_version, base_image, rollout) == :ok
    end

    test "returns error when version is not compatible with starting version requirement" do
      base_image = base_image_fixture(version: "2.3.0", starting_version_requirement: ">= 2.0.0")
      target_current_version = Version.parse!("1.7.0")
      rollout = push_rollout_fixture()

      assert Core.verify_compatibility(target_current_version, base_image, rollout) ==
               {:error, :version_requirement_not_matched}
    end

    test "returns :ok when version is compatible with starting version requirement" do
      base_image = base_image_fixture(version: "2.3.0", starting_version_requirement: "~> 2.1")
      target_current_version = Version.parse!("2.2.3")
      rollout = push_rollout_fixture()

      assert Core.verify_compatibility(target_current_version, base_image, rollout) == :ok
    end
  end

  test "mark_ota_operation_as_timed_out!/1" do
    import Edgehog.BaseImagesFixtures

    base_image = base_image_fixture()

    {:ok, target} =
      target_fixture()
      |> Core.preload_defaults_for_target()
      |> Core.start_target_update(base_image)

    ota_operation = Core.mark_ota_operation_as_timed_out!(target.ota_operation_id)

    assert ota_operation.status == :failure
    assert ota_operation.status_code == :request_timeout
  end

  test "mark_target_as_failed!/1" do
    completion_timestamp = ~U[2023-06-08 13:59:52.928623Z]

    target =
      target_fixture()
      |> Core.mark_target_as_failed!(completion_timestamp)

    assert target.status == :failed
    assert target.completion_timestamp == completion_timestamp
  end

  test "mark_target_as_successful!/1" do
    completion_timestamp = ~U[2023-06-08 13:59:52.928623Z]

    target =
      target_fixture()
      |> Core.mark_target_as_successful!(completion_timestamp)

    assert target.status == :successful
    assert target.completion_timestamp == completion_timestamp
  end

  describe "list_idle_targets/2" do
    test "requires limit" do
      update_campaign = update_campaign_fixture()

      assert_raise KeyError, fn -> Core.list_idle_targets(update_campaign.id) end
    end

    test "respects limit" do
      update_campaign = update_campaign_with_targets_fixture(100)

      targets = Core.list_idle_targets(update_campaign.id, limit: 10)
      assert length(targets) == 10
    end

    test "returns actual campaign targets" do
      update_campaign = update_campaign_with_targets_fixture(100)
      all_target_ids = MapSet.new(update_campaign.update_targets, & &1.id)

      targets = Core.list_idle_targets(update_campaign.id, limit: 10)
      Enum.each(targets, fn target -> MapSet.member?(all_target_ids, target.id) end)
    end

    test "returns less than limit if there are not enough targets" do
      update_campaign = update_campaign_with_targets_fixture(5)

      targets = Core.list_idle_targets(update_campaign.id, limit: 10)
      assert length(targets) == 5
    end

    test "does not return :pending targets" do
      update_campaign = update_campaign_with_targets_fixture(2)

      pending_target =
        Enum.at(update_campaign.update_targets, 0)
        |> Core.preload_defaults_for_target()
        |> Core.start_target_update(update_campaign.base_image)

      targets = Core.list_idle_targets(update_campaign.id, limit: 2)
      assert length(targets) == 1
      assert pending_target not in targets
    end

    test "does not return :successful targets" do
      update_campaign = update_campaign_with_targets_fixture(2)

      successful_target =
        Enum.at(update_campaign.update_targets, 0)
        |> Core.preload_defaults_for_target()
        |> Core.mark_target_as_successful!()

      targets = Core.list_idle_targets(update_campaign.id, limit: 2)
      assert length(targets) == 1
      assert successful_target not in targets
    end

    test "does not return :failed targets" do
      update_campaign = update_campaign_with_targets_fixture(2)

      failed_target =
        Enum.at(update_campaign.update_targets, 0)
        |> Core.preload_defaults_for_target()
        |> Core.mark_target_as_failed!()

      targets = Core.list_idle_targets(update_campaign.id, limit: 2)
      assert length(targets) == 1
      assert failed_target not in targets
    end

    test "only returns online targets if filter: [device_online: true] is passed" do
      update_campaign = update_campaign_with_targets_fixture(10)

      {online_targets, offline_targets} = Enum.split(update_campaign.update_targets, 3)

      online_targets
      |> Core.preload_defaults_for_target()
      |> Enum.each(&update_device_online_for_target(&1, true))

      online_target_ids = MapSet.new(online_targets, & &1.id)

      offline_targets
      |> Core.preload_defaults_for_target()
      |> Enum.each(&update_device_online_for_target(&1, false))

      targets =
        Core.list_idle_targets(update_campaign.id, limit: 10, filters: [device_online: true])

      assert length(targets) == 3
      Enum.each(targets, fn target -> MapSet.member?(online_target_ids, target.id) end)
    end

    test "returns targets without any attempts first" do
      update_campaign = update_campaign_with_targets_fixture(2)

      [target_with_attempt, target_with_no_attempt] = update_campaign.update_targets

      Core.update_target_latest_attempt!(target_with_attempt, DateTime.utc_now())

      [target] = Core.list_idle_targets(update_campaign.id, limit: 1)
      assert target.id == target_with_no_attempt.id
    end

    test "returns targets with oldest attempt first" do
      update_campaign = update_campaign_with_targets_fixture(2)

      [target_with_old_attempt, target_with_recent_attempt] = update_campaign.update_targets

      recent_attempt_timestamp = DateTime.utc_now()
      Core.update_target_latest_attempt!(target_with_recent_attempt, recent_attempt_timestamp)

      old_attempt_timestamp = DateTime.add(recent_attempt_timestamp, -10, :hour)
      Core.update_target_latest_attempt!(target_with_old_attempt, old_attempt_timestamp)

      [target] = Core.list_idle_targets(update_campaign.id, limit: 1)
      assert target.id == target_with_old_attempt.id
    end
  end

  describe "fetch_next_updatable_target/1" do
    test "does not return :pending targets" do
      update_campaign = update_campaign_with_targets_fixture(2)

      [pending_target, idle_target] = update_campaign.update_targets

      pending_target
      |> Core.preload_defaults_for_target()
      |> Core.start_target_update(update_campaign.base_image)

      assert {:ok, target} = Core.fetch_next_updatable_target(update_campaign.id)
      assert target.id == idle_target.id
    end

    test "does not return :successful targets" do
      update_campaign = update_campaign_with_targets_fixture(2)

      [successful_target, idle_target] = update_campaign.update_targets

      successful_target
      |> Core.preload_defaults_for_target()
      |> Core.mark_target_as_successful!()

      assert {:ok, target} = Core.fetch_next_updatable_target(update_campaign.id)
      assert target.id == idle_target.id
    end

    test "only returns online targets" do
      update_campaign = update_campaign_with_targets_fixture(2)

      [online_target, offline_target] = update_campaign.update_targets

      online_target
      |> Core.preload_defaults_for_target()
      |> update_device_online_for_target(true)

      offline_target
      |> Core.preload_defaults_for_target()
      |> update_device_online_for_target(false)

      assert {:ok, target} = Core.fetch_next_updatable_target(update_campaign.id)
      assert target.id == online_target.id
    end

    test "returns targets without any attempts first" do
      update_campaign = update_campaign_with_targets_fixture(2)

      [target_with_attempt, target_with_no_attempt] = update_campaign.update_targets

      Core.update_target_latest_attempt!(target_with_attempt, DateTime.utc_now())

      assert {:ok, target} = Core.fetch_next_updatable_target(update_campaign.id)
      assert target.id == target_with_no_attempt.id
    end

    test "returns targets with oldest attempt first" do
      update_campaign = update_campaign_with_targets_fixture(2)

      [target_with_old_attempt, target_with_recent_attempt] = update_campaign.update_targets

      recent_attempt_timestamp = DateTime.utc_now()
      Core.update_target_latest_attempt!(target_with_recent_attempt, recent_attempt_timestamp)

      old_attempt_timestamp = DateTime.add(recent_attempt_timestamp, -10, :hour)
      Core.update_target_latest_attempt!(target_with_old_attempt, old_attempt_timestamp)

      assert {:ok, target} = Core.fetch_next_updatable_target(update_campaign.id)
      assert target.id == target_with_old_attempt.id
    end

    test "returns {:error, :no_updatable_targets} with no updatable targets" do
      update_campaign = update_campaign_with_targets_fixture(2)

      [successful_target, offline_target] = update_campaign.update_targets

      successful_target
      |> Core.preload_defaults_for_target()
      |> Core.mark_target_as_successful!()

      offline_target
      |> Core.preload_defaults_for_target()
      |> update_device_online_for_target(false)

      assert {:error, :no_updatable_targets} =
               Core.fetch_next_updatable_target(update_campaign.id)
    end
  end

  describe "subscribe_to_ota_operation_updates/1" do
    alias Edgehog.OSManagement

    test "makes the process receive OTA Operation updates" do
      ota_operation = managed_ota_operation_fixture()

      Core.subscribe_to_ota_operation_updates!(ota_operation.id)

      # Generate a publish on the PubSub
      OSManagement.update_ota_operation(ota_operation, %{status: "Acknowledged"})

      assert_receive {:ota_operation_updated, %OSManagement.OTAOperation{status: :acknowledged}}
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
        "connection refused",
        %APIError{status: 422, response: "Invalid entity"},
        %APIError{status: 500, response: "Internal server error"}
      ]

      for error <- known_errors do
        msg = Core.error_message(error, ctx.device_id)
        assert msg =~ ctx.device_id
        assert not (msg =~ "failed with unknown error")
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
    alias Edgehog.OSManagement

    test "returns true for OTA Operation with status acknowledged" do
      {:ok, ota_operation} =
        managed_ota_operation_fixture()
        |> OSManagement.update_ota_operation(%{status: :acknowledged})

      assert Core.ota_operation_acknowledged?(ota_operation) == true
    end

    test "returns false for OTA Operation with other status" do
      {:ok, ota_operation} =
        managed_ota_operation_fixture()
        |> OSManagement.update_ota_operation(%{status: :downloading})

      assert Core.ota_operation_acknowledged?(ota_operation) == false
    end
  end

  describe "ota_operation_successful?/1" do
    alias Edgehog.OSManagement

    test "returns true for OTA Operation with status success" do
      {:ok, ota_operation} =
        managed_ota_operation_fixture()
        |> OSManagement.update_ota_operation(%{status: :success})

      assert Core.ota_operation_successful?(ota_operation) == true
    end

    test "returns false for OTA Operation with other status" do
      {:ok, ota_operation} =
        managed_ota_operation_fixture()
        |> OSManagement.update_ota_operation(%{status: :rebooting})

      assert Core.ota_operation_successful?(ota_operation) == false
    end
  end

  describe "ota_operation_failed?/1" do
    alias Edgehog.OSManagement

    test "returns true for OTA Operation with status failure" do
      {:ok, ota_operation} =
        managed_ota_operation_fixture()
        |> OSManagement.update_ota_operation(%{status: :failure})

      assert Core.ota_operation_failed?(ota_operation) == true
    end

    test "returns false for OTA Operation with other status" do
      {:ok, ota_operation} =
        managed_ota_operation_fixture()
        |> OSManagement.update_ota_operation(%{status: :deploying})

      assert Core.ota_operation_failed?(ota_operation) == false
    end
  end

  describe "failure_threshold_exceeded?" do
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

  test "get_target_count/1" do
    update_campaign = update_campaign_with_targets_fixture(42)

    assert Core.get_target_count(update_campaign.id) == 42
  end

  test "get_failed_target_count/1" do
    update_campaign = update_campaign_with_targets_fixture(10)

    # Call start_update/2 to mark targets as in_progress
    Enum.take(update_campaign.update_targets, 7)
    |> Enum.each(&Core.mark_target_as_failed!/1)

    assert Core.get_failed_target_count(update_campaign.id) == 7
  end

  test "get_in_progress_target_count/1" do
    update_campaign = update_campaign_with_targets_fixture(24)

    # Call start_update/2 to mark targets as in_progress
    Enum.take(update_campaign.update_targets, 11)
    |> Core.preload_defaults_for_target()
    |> Enum.each(&Core.start_target_update(&1, update_campaign.base_image))

    assert Core.get_in_progress_target_count(update_campaign.id) == 11
  end

  describe "has_idle_targets?/1" do
    test "returns true for campaigns with a least one idle target" do
      update_campaign = update_campaign_with_targets_fixture(5)

      Enum.take(update_campaign.update_targets, 4)
      |> Enum.each(&Core.mark_target_as_successful!/1)

      assert Core.has_idle_targets?(update_campaign.id) == true
    end

    test "returns false if all targets are in_progress" do
      update_campaign = update_campaign_with_targets_fixture(3)

      # Call start_update/2 to mark targets as in_progress
      update_campaign.update_targets
      |> Core.preload_defaults_for_target()
      |> Enum.each(&Core.start_target_update(&1, update_campaign.base_image))

      assert Core.has_idle_targets?(update_campaign.id) == false
    end

    test "returns false if all targets are successful" do
      update_campaign = update_campaign_with_targets_fixture(3)

      Enum.each(update_campaign.update_targets, &Core.mark_target_as_successful!/1)

      assert Core.has_idle_targets?(update_campaign.id) == false
    end

    test "returns false if all targets are failed" do
      update_campaign = update_campaign_with_targets_fixture(3)

      Enum.each(update_campaign.update_targets, &Core.mark_target_as_failed!/1)

      assert Core.has_idle_targets?(update_campaign.id) == false
    end

    test "returns false if campaign has no targets" do
      update_campaign = update_campaign_fixture()

      assert update_campaign.update_targets == []
      assert Core.has_idle_targets?(update_campaign.id) == false
    end
  end

  test "mark_update_campaign_as_in_progress!/1" do
    now = DateTime.utc_now()

    assert %UpdateCampaign{status: :in_progress, start_timestamp: ^now} =
             update_campaign_with_targets_fixture(3)
             |> Core.mark_update_campaign_as_in_progress!(now)
  end

  test "mark_update_campaign_as_failed!/1" do
    now = DateTime.utc_now()

    assert %UpdateCampaign{status: :finished, outcome: :failure, completion_timestamp: ^now} =
             update_campaign_with_targets_fixture(3)
             |> Core.mark_update_campaign_as_failed!(now)
  end

  test "mark_update_campaign_as_successful!/1" do
    now = DateTime.utc_now()

    assert %UpdateCampaign{status: :finished, outcome: :success, completion_timestamp: ^now} =
             update_campaign_with_targets_fixture(3)
             |> Core.mark_update_campaign_as_successful!(now)
  end

  describe "list_targets_with_pending_ota_operation/1" do
    alias Edgehog.OSManagement

    test "returns empty list if no target has pending ota operations" do
      update_campaign = update_campaign_with_targets_fixture(5)

      assert [] == Core.list_targets_with_pending_ota_operation(update_campaign.id)
    end

    test "returns target if it has a pending OTA Operation" do
      update_campaign = update_campaign_with_targets_fixture(5)

      assert {:ok, target} =
               update_campaign.update_targets
               |> hd()
               |> Core.preload_defaults_for_target()
               |> Core.start_target_update(update_campaign.base_image)

      assert [pending_ota_operation_target] =
               Core.list_targets_with_pending_ota_operation(update_campaign.id)

      assert pending_ota_operation_target.id == target.id
    end

    test "does not return target if its OTA Operation is in a different state" do
      update_campaign = update_campaign_with_targets_fixture(5)

      assert {:ok, target} =
               update_campaign.update_targets
               |> hd()
               |> Core.preload_defaults_for_target()
               |> Core.start_target_update(update_campaign.base_image)

      assert {:ok, _ota_operation} =
               OSManagement.get_ota_operation!(target.ota_operation_id)
               |> OSManagement.update_ota_operation(%{status: :acknowledged})

      assert [] == Core.list_targets_with_pending_ota_operation(update_campaign.id)
    end
  end

  defp push_rollout_fixture(attrs \\ []) do
    attrs
    |> Enum.into(%{
      max_failure_percentage: 5.0,
      max_in_progress_updates: 10
    })
    |> then(&struct!(PushRollout, &1))
  end

  defp update_device_online_for_target(target, online) do
    Astarte.get_device!(target.device.id)
    |> Astarte.update_device(%{online: online})
  end

  defp set_target_retry_count!(target, count) do
    assert target.retry_count == 0
    Enum.reduce(1..count, target, fn _idx, target -> Core.increase_retry_count!(target) end)
  end

  defp managed_ota_operation_fixture do
    # Helper to avoid having to manually create the cluster, realm and device
    # TODO: this will be eliminated once we have proper lazy fixtures (see issue #267)

    AstarteFixtures.cluster_fixture()
    |> AstarteFixtures.realm_fixture()
    |> DevicesFixtures.device_fixture()
    |> OSManagementFixtures.managed_ota_operation_fixture()
  end
end
