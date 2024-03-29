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

defmodule Edgehog.UpdateCampaignsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.UpdateCampaigns` context.
  """

  alias Edgehog.BaseImagesFixtures
  alias Edgehog.DevicesFixtures
  alias Edgehog.GroupsFixtures

  @doc """
  Generate a unique update_channel handle.
  """
  def unique_update_channel_handle, do: "some-handle#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique update_channel name.
  """
  def unique_update_channel_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique update_campaign name.
  """
  def unique_update_campaign_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a update_channel.
  """
  def update_channel_fixture(attrs \\ []) do
    {target_group_ids, attrs} =
      Keyword.pop_lazy(attrs, :target_group_ids, fn ->
        target_group = Edgehog.GroupsFixtures.device_group_fixture()
        [target_group.id]
      end)

    {:ok, update_channel} =
      attrs
      |> Enum.into(%{
        handle: unique_update_channel_handle(),
        name: unique_update_channel_name(),
        target_group_ids: target_group_ids
      })
      |> Edgehog.UpdateCampaigns.create_update_channel()

    update_channel
  end

  def update_campaign_fixture(attrs \\ []) do
    {update_channel, attrs} = Keyword.pop_lazy(attrs, :update_channel, &update_channel_fixture/0)

    {base_image, attrs} =
      Keyword.pop_lazy(attrs, :base_image, &Edgehog.BaseImagesFixtures.base_image_fixture/0)

    {rollout_mechanism_attrs, attrs} = Keyword.pop(attrs, :rollout_mechanism, [])

    rollout_mechanism_attrs =
      Enum.into(rollout_mechanism_attrs, %{
        type: "push",
        max_failure_percentage: 50.0,
        max_in_progress_updates: 100
      })

    attrs =
      Enum.into(attrs, %{
        name: unique_update_campaign_name(),
        rollout_mechanism: rollout_mechanism_attrs
      })

    {:ok, update_campaign} =
      Edgehog.UpdateCampaigns.create_update_campaign(update_channel, base_image, attrs)

    update_campaign
  end

  @doc """
  Generates an update campaign with N targets
  """
  def update_campaign_with_targets_fixture(target_count, attrs \\ [])
      when is_integer(target_count) and target_count > 0 do
    # Initializes an update campaign with N targets
    {base_image, attrs} =
      Keyword.pop_lazy(attrs, :base_image, &BaseImagesFixtures.base_image_fixture/0)

    tag = "foo"
    group = GroupsFixtures.device_group_fixture(selector: ~s<"#{tag}" in tags>)

    update_channel = update_channel_fixture(target_group_ids: [group.id])

    for _ <- 1..target_count do
      # Create devices as online by default
      _ =
        DevicesFixtures.device_fixture_compatible_with(base_image, online: true)
        |> DevicesFixtures.add_tags([tag])
    end

    attrs
    |> Keyword.merge(base_image: base_image, update_channel: update_channel)
    |> update_campaign_fixture()
  end

  @doc """
  Generates an idle update target
  """
  def target_fixture(attrs \\ []) do
    {base_image, attrs} =
      Keyword.pop_lazy(attrs, :base_image, &Edgehog.BaseImagesFixtures.base_image_fixture/0)

    {tag, attrs} = Keyword.pop(attrs, :tag, "foo")

    {group, attrs} =
      Keyword.pop_lazy(attrs, :device_group, fn ->
        GroupsFixtures.device_group_fixture(selector: ~s<"#{tag}" in tags>)
      end)

    {update_channel, attrs} =
      Keyword.pop_lazy(attrs, :update_channel, fn ->
        update_channel_fixture(target_group_ids: [group.id])
      end)

    _ =
      DevicesFixtures.device_fixture_compatible_with(base_image, attrs)
      |> DevicesFixtures.add_tags([tag])

    update_campaign =
      update_campaign_fixture(base_image: base_image, update_channel: update_channel)

    [target] = update_campaign.update_targets

    target
  end

  @doc """
  Generates an update target with an associated OTA Operation
  """
  def in_progress_target_fixture(opts \\ []) do
    alias Edgehog.UpdateCampaigns.PushRollout.Core

    now = Keyword.get(opts, :now, DateTime.utc_now())

    # A little dance to create a target_fixture which has an associated OTA Operation
    target =
      target_fixture(opts)
      |> Core.preload_defaults_for_target()

    base_image = Core.get_update_campaign_base_image!(target.update_campaign_id)

    # Stub Astarte Device Status and OTA Request
    Mox.stub_with(
      Edgehog.Astarte.Device.DeviceStatusMock,
      Edgehog.Mocks.Astarte.Device.DeviceStatus
    )

    Mox.stub_with(
      Edgehog.Astarte.Device.OTARequestV1Mock,
      Edgehog.Mocks.Astarte.Device.OTARequest.V1
    )

    {:ok, target} =
      target
      |> Core.update_target_latest_attempt!(now)
      |> Core.start_target_update(base_image)

    target
  end

  @doc """
  Generates a terminated update target with a success status
  This also sets the correct termination status to the associated OTA Operation.
  """
  def successful_target_fixture(opts \\ []) do
    terminated_target_fixture(opts, :success)
  end

  @doc """
  Generates a terminated update target with a failure status.
  This also sets the correct termination status to the associated OTA Operation.
  """
  def failed_target_fixture(opts \\ []) do
    terminated_target_fixture(opts, :failure)
  end

  defp terminated_target_fixture(opts, status) do
    alias Edgehog.OSManagement
    alias Edgehog.UpdateCampaigns.PushRollout.Core
    alias Edgehog.UpdateCampaigns

    now = Keyword.get(opts, :now, DateTime.utc_now())

    target = in_progress_target_fixture(opts)

    {:ok, _} =
      target.ota_operation_id
      |> OSManagement.get_ota_operation!()
      |> OSManagement.update_ota_operation(%{status: status})

    # Fetch the target again so we get the updated OTA Operation preloaded
    {:ok, target} = UpdateCampaigns.fetch_target(target.id)

    case status do
      :failure ->
        Core.mark_target_as_failed!(target, now)

      :success ->
        Core.mark_target_as_successful!(target, now)
    end
  end
end
