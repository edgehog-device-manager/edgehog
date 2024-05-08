#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.UpdateChannel.Changes.RelateTargetGroups do
  use Ash.Resource.Change

  alias Edgehog.Groups.DeviceGroup

  @impl true
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context

    {:ok, target_group_ids} = Ash.Changeset.fetch_argument(changeset, :target_group_ids)

    Ash.Changeset.after_action(changeset, fn _changeset, update_channel ->
      relate_target_groups(tenant, update_channel, target_group_ids)
    end)
  end

  defp relate_target_groups(tenant, update_channel, target_group_ids) do
    %Ash.BulkResult{status: status, records: records} =
      DeviceGroup
      |> Ash.Query.filter(id in ^target_group_ids)
      |> Ash.Query.filter(is_nil(update_channel_id))
      |> Ash.Query.set_tenant(tenant)
      |> Ash.bulk_update(:update_update_channel, %{update_channel_id: update_channel.id},
        return_records?: true
      )

    if status == :success and length(records) == length(target_group_ids) do
      {:ok, update_channel}
    else
      {:error,
       Ash.Error.Changes.InvalidArgument.exception(
         field: :target_group_ids,
         message:
           "some target groups were not found or are already associated with an update channel"
       )}
    end
  end
end
