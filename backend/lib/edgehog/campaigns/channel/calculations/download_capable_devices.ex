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

defmodule Edgehog.Campaigns.Channel.Calculations.DownloadCapableDevices do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Edgehog.Selector

  require Ash.Query

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context) do
    [target_groups: [:selector]]
  end

  @impl Ash.Resource.Calculation
  def calculate(channels, _opts, context) do
    channels
    |> Ash.load!(target_groups: [:selector])
    |> Enum.map(&resolve_channel(&1, context))
  end

  defp resolve_channel(channel, context) do
    combined_expr = Enum.reduce(channel.target_groups, nil, &combine_selectors/2)

    if combined_expr do
      Edgehog.Devices.Device
      |> Ash.Query.filter(^combined_expr)
      |> Ash.Query.set_tenant(context.tenant)
      |> Ash.read!()
    else
      []
    end
  end

  defp combine_selectors(group, acc) do
    case Selector.parse(group.selector) do
      {:ok, ast} ->
        expr = Selector.to_ash_expr(ast)
        if acc, do: Ash.Expr.expr(^expr or ^acc), else: expr

      _ ->
        acc
    end
  end
end
