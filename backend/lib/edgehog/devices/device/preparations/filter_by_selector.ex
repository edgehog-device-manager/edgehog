#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Devices.Device.Preparations.FilterBySelector do
  @moduledoc false
  use Ash.Resource.Preparation

  alias Edgehog.Selector

  require Ash.Query

  @impl Ash.Resource.Preparation
  def prepare(query, _opts, context) do
    selector_string = get_selector(query, context)

    if selector_string do
      {:ok, ast} = Selector.parse(selector_string)
      ash_expr = Selector.to_ash_expr(ast)
      Ash.Query.filter(query, ^ash_expr)
    else
      query
    end
  end

  defp get_selector(query, context) do
    selector = Ash.Query.get_argument(query, :matching_selector)
    group_id = Ash.Query.get_argument(query, :matching_group_id)

    cond do
      is_binary(selector) ->
        selector

      group_id != nil ->
        group =
          Edgehog.Groups.DeviceGroup
          |> Ash.Query.filter(id == ^group_id)
          |> Ash.Query.set_tenant(context.tenant)
          |> Ash.read_first!()

        if group, do: group.selector, else: nil

      true ->
        nil
    end
  end
end
