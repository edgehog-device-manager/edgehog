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

  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Edgehog.Groups
  alias Edgehog.UpdateCampaigns
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
end
