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

defmodule Edgehog.UpdateCampaigns.UpdateChannel.Validations.TargetGroupsAreAvailable do
  @moduledoc false

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidArgument
  alias Edgehog.Groups.DeviceGroup

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, context) do
    %{tenant: tenant} = context

    {:ok, target_group_ids} = Ash.Changeset.fetch_argument(changeset, :target_group_ids)

    {:ok, target_groups} =
      DeviceGroup
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.filter(id in ^target_group_ids)
      |> Ash.read()

    read_groups_ids = Enum.map(target_groups, & &1.id)

    not_found_groups =
      Enum.reject(target_group_ids, &(&1 in read_groups_ids))

    if Enum.empty?(not_found_groups),
      do: :ok,
      else:
        {:error,
         InvalidArgument.exception(
           field: :target_group_ids,
           message: "some target groups were not found: #{inspect(not_found_groups, charlists: :as_list)}"
         )}
  end
end
