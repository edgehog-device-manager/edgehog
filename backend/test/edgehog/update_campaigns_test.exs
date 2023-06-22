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

defmodule Edgehog.UpdateCampaignsTest do
  use Edgehog.DataCase

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Edgehog.AstarteFixtures
  alias Edgehog.DevicesFixtures
  alias Edgehog.Groups
  alias Edgehog.UpdateCampaigns
  alias Edgehog.UpdateCampaigns.ExecutorRegistry
  alias Edgehog.UpdateCampaigns.PushRollout
  alias Edgehog.UpdateCampaigns.UpdateCampaign
  alias Edgehog.UpdateCampaigns.UpdateChannel

  test "list_update_channels/0 returns all update_channels" do
    update_channel = update_channel_fixture()
    assert UpdateCampaigns.list_update_channels() == [update_channel]
  end

  describe "fetch_update_channel/1" do
    test "returns the update_channel with given id" do
      update_channel = update_channel_fixture()
      assert UpdateCampaigns.fetch_update_channel(update_channel.id) == {:ok, update_channel}
    end

    test "returns {:error, :not_found} for non-existing id" do
      assert UpdateCampaigns.fetch_update_channel(1_234_567) == {:error, :not_found}
    end
  end

  describe "create_update_channel/1" do
    test "with valid data creates a update_channel" do
      target_group = device_group_fixture()
      attrs = %{handle: "some-handle", name: "some name", target_group_ids: [target_group.id]}

      assert {:ok, %UpdateChannel{} = update_channel} =
               UpdateCampaigns.create_update_channel(attrs)

      assert update_channel.handle == "some-handle"
      assert update_channel.name == "some name"
      {:ok, target_group} = Groups.fetch_device_group(target_group.id)
      assert target_group.update_channel_id == update_channel.id
    end

    test "with empty handle returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = create_update_channel(handle: nil)

      assert "can't be blank" in errors_on(changeset).handle
    end

    test "with invalid handle returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_update_channel(handle: "Invalid Format")

      error_msg =
        "should start with a lower case ASCII letter and only contain lower case ASCII letters, digits and -"

      assert error_msg in errors_on(changeset).handle
    end

    test "with empty name returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = create_update_channel(name: nil)

      assert "can't be blank" in errors_on(changeset).name
    end

    test "with non-unique handle fails" do
      _ = update_channel_fixture(handle: "foobar")

      assert {:error, %Ecto.Changeset{} = changeset} = create_update_channel(handle: "foobar")

      assert "has already been taken" in errors_on(changeset).handle
    end

    test "with non-unique name fails" do
      _ = update_channel_fixture(name: "foobar")

      assert {:error, %Ecto.Changeset{} = changeset} = create_update_channel(name: "foobar")

      assert "has already been taken" in errors_on(changeset).name
    end

    test "with nil target_group_ids returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_update_channel(target_group_ids: nil)

      assert "can't be blank" in errors_on(changeset).target_group_ids
    end

    test "with empty target_group_ids returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = create_update_channel(target_group_ids: [])

      assert "should have at least 1 item(s)" in errors_on(changeset).target_group_ids
    end

    test "with already assigned target_group_ids returns error" do
      target_group = device_group_fixture()
      _conflicting_update_channel = update_channel_fixture(target_group_ids: [target_group.id])

      assert {:error, %Ecto.Changeset{} = changeset} =
               create_update_channel(target_group_ids: [target_group.id])

      assert "contains #{target_group.id}, which is already assigned to another update channel" in errors_on(
               changeset
             ).target_group_ids
    end

    test "with non-existing target_group_ids returns error" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_update_channel(target_group_ids: [1_234_567])

      assert "contains 1234567, which is not an existing target group" in errors_on(changeset).target_group_ids
    end
  end

  describe "update_update_channel/2" do
    setup do
      {:ok, update_channel: update_channel_fixture()}
    end

    test "with valid data updates the update_channel", %{update_channel: update_channel} do
      [%{id: old_target_group_id}] = update_channel.target_groups

      new_target_group = device_group_fixture()

      attrs = %{
        handle: "some-updated-handle",
        name: "some updated name",
        target_group_ids: [new_target_group.id]
      }

      assert {:ok, %UpdateChannel{} = update_channel} =
               UpdateCampaigns.update_update_channel(update_channel, attrs)

      assert update_channel.handle == "some-updated-handle"
      assert update_channel.name == "some updated name"

      {:ok, new_target_group} = Groups.fetch_device_group(new_target_group.id)
      assert new_target_group.update_channel_id == update_channel.id
      {:ok, old_target_group} = Groups.fetch_device_group(old_target_group_id)
      assert old_target_group.update_channel_id == nil
    end

    test "with empty handle returns error changeset", %{update_channel: update_channel} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               update_update_channel(update_channel, handle: nil)

      assert "can't be blank" in errors_on(changeset).handle
    end

    test "with invalid handle returns error changeset", %{update_channel: update_channel} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               update_update_channel(update_channel, handle: "Invalid Format")

      error_msg =
        "should start with a lower case ASCII letter and only contain lower case ASCII letters, digits and -"

      assert error_msg in errors_on(changeset).handle
    end

    test "with empty name returns error changeset", %{update_channel: update_channel} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               update_update_channel(update_channel, name: nil)

      assert "can't be blank" in errors_on(changeset).name
    end

    test "with non-unique handle fails", %{update_channel: update_channel} do
      _ = update_channel_fixture(handle: "foobar")

      assert {:error, %Ecto.Changeset{} = changeset} =
               update_update_channel(update_channel, handle: "foobar")

      assert "has already been taken" in errors_on(changeset).handle
    end

    test "with non-unique name fails", %{update_channel: update_channel} do
      _ = update_channel_fixture(name: "foobar")

      assert {:error, %Ecto.Changeset{} = changeset} =
               update_update_channel(update_channel, name: "foobar")

      assert "has already been taken" in errors_on(changeset).name
    end

    test "with empty target_group_ids returns error changeset", %{update_channel: update_channel} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               update_update_channel(update_channel, target_group_ids: [])

      assert "should have at least 1 item(s)" in errors_on(changeset).target_group_ids
    end

    test "with already assigned target_group_ids returns error", %{update_channel: update_channel} do
      target_group = device_group_fixture()
      _conflicting_update_channel = update_channel_fixture(target_group_ids: [target_group.id])

      assert {:error, %Ecto.Changeset{} = changeset} =
               update_update_channel(update_channel, target_group_ids: [target_group.id])

      assert "contains #{target_group.id}, which is already assigned to another update channel" in errors_on(
               changeset
             ).target_group_ids
    end

    test "with non-existing target_group_ids returns error", %{update_channel: update_channel} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               update_update_channel(update_channel, target_group_ids: [1_234_567])

      assert "contains 1234567, which is not an existing target group" in errors_on(changeset).target_group_ids
    end
  end

  describe "delete_update_channel/1" do
    setup do
      {:ok, update_channel: update_channel_fixture()}
    end

    test "deletes the update_channel", %{update_channel: update_channel} do
      assert {:ok, %UpdateChannel{}} = UpdateCampaigns.delete_update_channel(update_channel)
      assert UpdateCampaigns.fetch_update_channel(update_channel.id) == {:error, :not_found}
    end

    test "unassigns the associated target groups", %{update_channel: update_channel} do
      [%{id: target_group_id}] = update_channel.target_groups
      assert {:ok, %UpdateChannel{}} = UpdateCampaigns.delete_update_channel(update_channel)
      {:ok, target_group} = Groups.fetch_device_group(target_group_id)
      assert target_group.update_channel_id == nil
    end
  end

  test "change_update_channel/1 returns a update_channel changeset" do
    update_channel = update_channel_fixture()
    assert %Ecto.Changeset{} = UpdateCampaigns.change_update_channel(update_channel)
  end

  test "get_update_channels_for_device_group_ids/1 returns the correct result" do
    target_group_1 = device_group_fixture()
    target_group_2 = device_group_fixture()
    target_group_3 = device_group_fixture()
    target_group_4 = device_group_fixture()

    update_channel_1 = update_channel_fixture(target_group_ids: [target_group_1.id])

    update_channel_2 =
      update_channel_fixture(target_group_ids: [target_group_2.id, target_group_3.id])

    target_group_ids = [
      target_group_1.id,
      target_group_2.id,
      target_group_3.id,
      target_group_4.id
    ]

    assert update_channels_map =
             UpdateCampaigns.get_update_channels_for_device_group_ids(target_group_ids)

    assert is_map(update_channels_map)
    assert length(Map.keys(update_channels_map)) == length(target_group_ids)
    assert %UpdateChannel{id: id} = Map.fetch!(update_channels_map, target_group_1.id)
    assert id == update_channel_1.id
    assert %UpdateChannel{id: id} = Map.fetch!(update_channels_map, target_group_2.id)
    assert id == update_channel_2.id
    assert %UpdateChannel{id: id} = Map.fetch!(update_channels_map, target_group_3.id)
    assert id == update_channel_2.id
    assert Map.fetch!(update_channels_map, target_group_4.id) == nil
  end

  test "list_update_campaigns/0 returns all update campaigns" do
    update_campaign = update_campaign_fixture()
    assert UpdateCampaigns.list_update_campaigns() == [update_campaign]
  end

  describe "fetch_update_campaign/1" do
    test "returns the update_campaign with given id" do
      update_campaign = update_campaign_fixture()
      assert UpdateCampaigns.fetch_update_campaign(update_campaign.id) == {:ok, update_campaign}
    end

    test "returns {:error, :not_found} for non-existing id" do
      assert UpdateCampaigns.fetch_update_campaign(1_234_567) == {:error, :not_found}
    end
  end

  describe "create_update_campaign/3" do
    test "with valid data creates an update_campaign" do
      update_channel = update_channel_fixture()
      base_image = base_image_fixture()

      attrs = %{
        name: "My Campaign",
        rollout_mechanism: %{
          type: "push",
          max_errors_percentage: 10.0,
          max_in_progress_updates: 10
        }
      }

      assert {:ok, %UpdateCampaign{} = update_campaign} =
               UpdateCampaigns.create_update_campaign(update_channel, base_image, attrs)

      assert %PushRollout{
               max_errors_percentage: 10.0,
               max_in_progress_updates: 10,
               # Default value
               ota_request_retries: 0,
               # Default value
               ota_request_timeout_seconds: 60,
               # Default value
               force_downgrade: false
             } = update_campaign.rollout_mechanism
    end

    test "with no targets creates a update_campaign that succeeds immediately" do
      {:ok, update_campaign} = create_update_campaign()

      assert update_campaign.update_targets == []
      assert update_campaign.status == :finished
      assert update_campaign.outcome == :success

      # Check that no executor got started
      assert :error = fetch_update_campaign_executor_pid(update_campaign)
    end

    test "with some targets creates an :idle update_campaign" do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>)
      update_channel = update_channel_fixture(target_group_ids: [target_group.id])

      base_image = base_image_fixture()

      device =
        device_fixture_compatible_with(base_image)
        |> add_tags(["foobar"])

      {:ok, update_campaign} =
        create_update_campaign(update_channel: update_channel, base_image: base_image)

      assert [target] = update_campaign.update_targets
      assert target.device_id == device.id
      assert update_campaign.status == :idle
      assert update_campaign.outcome == nil

      # Check that the executor got started
      assert {:ok, pid} = fetch_update_campaign_executor_pid(update_campaign)
      assert {:wait_for_start_execution, _data} = :sys.get_state(pid)
    end

    test "fails with invalid rollout mechanism" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_update_campaign(rollout_mechanism: [type: "invalid"])

      assert "is invalid" in errors_on(changeset).rollout_mechanism
    end

    test "fails with invalid max_errors_percentage in rollout_mechanism" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_update_campaign(rollout_mechanism: [max_errors_percentage: 120.0])

      assert "must be less than or equal to 100" in errors_on(changeset).rollout_mechanism.max_errors_percentage
    end

    test "fails with invalid max_in_progress_updates in rollout_mechanism" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_update_campaign(rollout_mechanism: [max_in_progress_updates: -3])

      assert "must be greater than or equal to 1" in errors_on(changeset).rollout_mechanism.max_in_progress_updates
    end

    test "saves ota_request_retries in rollout_mechanism if explicitly passed" do
      {:ok, update_campaign} = create_update_campaign(rollout_mechanism: [ota_request_retries: 5])

      assert update_campaign.rollout_mechanism.ota_request_retries == 5
    end

    test "fails with invalid ota_request_retries in rollout_mechanism" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_update_campaign(rollout_mechanism: [ota_request_retries: -5])

      assert "must be greater than or equal to 0" in errors_on(changeset).rollout_mechanism.ota_request_retries
    end

    test "saves ota_request_timeout_seconds in rollout_mechanism if explicitly passed" do
      {:ok, update_campaign} =
        create_update_campaign(rollout_mechanism: [ota_request_timeout_seconds: 120])

      assert update_campaign.rollout_mechanism.ota_request_timeout_seconds == 120
    end

    test "fails with invalid ota_request_timeout_seconds in rollout_mechanism" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_update_campaign(rollout_mechanism: [ota_request_timeout_seconds: 5])

      assert "must be greater than or equal to 30" in errors_on(changeset).rollout_mechanism.ota_request_timeout_seconds
    end

    test "saves force_downgrade in rollout_mechanism if explicitly passed" do
      {:ok, update_campaign} = create_update_campaign(rollout_mechanism: [force_downgrade: true])

      assert update_campaign.rollout_mechanism.force_downgrade == true
    end

    test "fails with invalid force_downgrade in rollout_mechanism" do
      assert {:error, %Ecto.Changeset{}} =
               create_update_campaign(rollout_mechanism: [force_downgrade: "foo"])

      # TODO: add assertions on the specific error key after errors_on gets fixed to work on
      # nested changeset errors
    end
  end

  describe "update_update_campaign/2" do
    test "allows updating rollout_mechanism with an equal or higher max_in_progress_update" do
      original_max_in_progress_updates = 3

      {:ok, update_campaign} =
        create_update_campaign(
          rollout_mechanism: [max_in_progress_updates: original_max_in_progress_updates]
        )

      assert {:ok, updated_update_campaign} =
               UpdateCampaigns.update_update_campaign(update_campaign, %{
                 rollout_mechanism: %{
                   type: "push",
                   max_in_progress_updates: original_max_in_progress_updates
                 }
               })

      assert updated_update_campaign.rollout_mechanism.max_in_progress_updates ==
               original_max_in_progress_updates

      assert {:ok, updated_update_campaign} =
               UpdateCampaigns.update_update_campaign(update_campaign, %{
                 rollout_mechanism: %{
                   type: "push",
                   max_in_progress_updates: original_max_in_progress_updates + 1
                 }
               })

      assert updated_update_campaign.rollout_mechanism.max_in_progress_updates ==
               original_max_in_progress_updates + 1
    end

    test "fails updating rollout_mechanism with a lower max_in_progress_update" do
      original_max_in_progress_updates = 3

      {:ok, update_campaign} =
        create_update_campaign(
          rollout_mechanism: [max_in_progress_updates: original_max_in_progress_updates]
        )

      assert {:error, %Ecto.Changeset{} = changeset} =
               UpdateCampaigns.update_update_campaign(
                 update_campaign,
                 %{
                   rollout_mechanism: %{
                     type: "push",
                     max_in_progress_updates: original_max_in_progress_updates - 1
                   }
                 }
               )

      assert "must be greater than or equal to #{original_max_in_progress_updates}" in errors_on(
               changeset
             ).rollout_mechanism.max_in_progress_updates
    end
  end

  describe "list_updatable_devices" do
    test "returns empty list without devices" do
      update_channel = update_channel_fixture()
      base_image = base_image_fixture()

      assert UpdateCampaigns.list_updatable_devices(update_channel, base_image) == []
    end

    test "returns only devices matching the system model of the base_image" do
      base_image = base_image_fixture()

      target_group = device_group_fixture(selector: ~s<"foobar" in tags>)
      update_channel = update_channel_fixture(target_group_ids: [target_group.id])

      device =
        device_fixture_compatible_with(base_image)
        |> add_tags(["foobar"])

      _other_device =
        device_fixture()
        |> add_tags(["foobar"])

      assert UpdateCampaigns.list_updatable_devices(update_channel, base_image) == [device]
    end

    test "returns only devices belonging to the UpdateChannel with the base_image" do
      base_image = base_image_fixture()

      target_group = device_group_fixture(selector: ~s<"foobar" in tags>)
      update_channel = update_channel_fixture(target_group_ids: [target_group.id])

      device =
        device_fixture_compatible_with(base_image)
        |> add_tags(["foobar"])

      _other_device =
        device_fixture_compatible_with(base_image)
        |> add_tags(["not-foobar"])

      assert UpdateCampaigns.list_updatable_devices(update_channel, base_image) == [device]
    end

    test "returns the union of all target groups of the UpdateChannel" do
      base_image = base_image_fixture()

      foo_group = device_group_fixture(selector: ~s<"foo" in tags>)
      bar_group = device_group_fixture(selector: ~s<"bar" in tags>)
      update_channel = update_channel_fixture(target_group_ids: [foo_group.id, bar_group.id])

      foo_device =
        device_fixture_compatible_with(base_image)
        |> add_tags(["foo"])

      bar_device =
        device_fixture_compatible_with(base_image)
        |> add_tags(["bar"])

      updatable_devices = UpdateCampaigns.list_updatable_devices(update_channel, base_image)
      assert length(updatable_devices) == 2
      assert foo_device in updatable_devices
      assert bar_device in updatable_devices
    end

    test "deduplicates devices belonging to multiple groups" do
      base_image = base_image_fixture()

      foo_group = device_group_fixture(selector: ~s<"foo" in tags>)
      bar_group = device_group_fixture(selector: ~s<"bar" in tags>)
      update_channel = update_channel_fixture(target_group_ids: [foo_group.id, bar_group.id])

      device =
        device_fixture_compatible_with(base_image)
        |> add_tags(["foo", "bar"])

      assert UpdateCampaigns.list_updatable_devices(update_channel, base_image) == [device]
    end
  end

  defp create_update_channel(opts) do
    {target_group_ids, opts} =
      Keyword.pop_lazy(opts, :target_group_ids, fn ->
        target_group = device_group_fixture()
        [target_group.id]
      end)

    opts
    |> Enum.into(%{
      handle: unique_update_channel_handle(),
      name: unique_update_channel_name(),
      target_group_ids: target_group_ids
    })
    |> Edgehog.UpdateCampaigns.create_update_channel()
  end

  defp update_update_channel(update_channel, opts) do
    attrs = Enum.into(opts, %{})

    Edgehog.UpdateCampaigns.update_update_channel(update_channel, attrs)
  end

  defp create_update_campaign(opts \\ []) do
    {update_channel, opts} =
      Keyword.pop_lazy(opts, :update_channel, fn ->
        update_channel_fixture()
      end)

    {base_image, opts} =
      Keyword.pop_lazy(opts, :base_image, fn ->
        base_image_fixture()
      end)

    {rollout_mechanism_opts, opts} = Keyword.pop(opts, :rollout_mechanism, [])

    rollout_mechanism =
      Enum.into(rollout_mechanism_opts, %{
        type: "push",
        max_errors_percentage: 10.0,
        max_in_progress_updates: 10
      })

    attrs =
      Enum.into(opts, %{
        name: unique_update_campaign_name(),
        rollout_mechanism: rollout_mechanism
      })

    UpdateCampaigns.create_update_campaign(update_channel, base_image, attrs)
  end

  defp fetch_update_campaign_executor_pid(update_campaign) do
    key = {update_campaign.tenant_id, update_campaign.id}

    case Registry.lookup(ExecutorRegistry, key) do
      [] -> :error
      [{pid, _}] -> {:ok, pid}
    end
  end

  defp device_fixture do
    # Helper to avoid having to manually create the cluster and realm
    # TODO: this will be eliminated once we have proper lazy fixtures (see issue #267)

    AstarteFixtures.cluster_fixture()
    |> AstarteFixtures.realm_fixture()
    |> DevicesFixtures.device_fixture()
  end
end
