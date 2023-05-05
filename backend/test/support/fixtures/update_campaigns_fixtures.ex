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

    attrs =
      Enum.into(attrs, %{
        name: unique_update_campaign_name(),
        rollout_mechanism: %{
          type: "push",
          max_errors_percentage: 10.0,
          max_in_progress_updates: 10
        }
      })

    {:ok, update_campaign} =
      Edgehog.UpdateCampaigns.create_update_campaign(update_channel, base_image, attrs)

    update_campaign
  end

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
end
