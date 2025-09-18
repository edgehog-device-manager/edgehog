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

defmodule Edgehog.Campaigns.Channel.Changes.UnrelateCurrentTargetGroups do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Groups.DeviceGroup

  require Ash.Query

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context

    Ash.Changeset.before_action(changeset, fn changeset ->
      unrelate_target_groups(tenant, changeset)
    end)
  end

  defp unrelate_target_groups(tenant, changeset) do
    channel_id = changeset.data.id

    %Ash.BulkResult{status: :success} =
      DeviceGroup
      |> Ash.Query.filter(channel_id == ^channel_id)
      |> Ash.Query.set_tenant(tenant)
      |> Ash.bulk_update!(:unassign_channel, %{})

    changeset
  end
end
