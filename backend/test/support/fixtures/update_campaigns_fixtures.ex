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

  @doc """
  Generate a unique update_channel handle.
  """
  def unique_update_channel_handle, do: "some-handle#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique update_channel name.
  """
  def unique_update_channel_name, do: "some name#{System.unique_integer([:positive])}"

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
end
