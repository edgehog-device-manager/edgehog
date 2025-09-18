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

defmodule Edgehog.CampaignsFixtures do
  @moduledoc false

  @doc """
  Generate a unique channel handle.
  """
  def unique_channel_handle, do: "some-handle#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique channel name.
  """
  def unique_channel_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a channel.
  """
  def channel_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {target_group_ids, opts} =
      Keyword.pop_lazy(opts, :target_group_ids, fn ->
        target_group = Edgehog.GroupsFixtures.device_group_fixture(tenant: tenant)
        [target_group.id]
      end)

    params =
      Enum.into(opts, %{
        handle: unique_channel_handle(),
        name: unique_channel_name(),
        target_group_ids: target_group_ids
      })

    Edgehog.Campaigns.Channel
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end
end
