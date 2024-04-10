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

defmodule Edgehog.Groups.DeviceGroup.ManualRelationships.Devices do
  use Ash.Resource.ManualRelationship

  alias Edgehog.Selector
  require Ash.Query

  @impl true
  def select(_opts) do
    [:selector]
  end

  @impl true
  def load(groups, _opts, %{query: query}) do
    # We're doing N+1 queries here, but it's probably inevitable at this point
    group_id_to_devices =
      groups
      |> Enum.map(fn group ->
        {:ok, ast_root} = Selector.parse(group.selector)

        filter = Selector.to_ash_expr(ast_root)

        devices =
          query
          |> Ash.Query.filter(^filter)
          |> Ash.read!()

        {group.id, devices}
      end)
      |> Map.new()

    {:ok, group_id_to_devices}
  end
end
