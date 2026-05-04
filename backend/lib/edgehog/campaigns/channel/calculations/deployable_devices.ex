#
# This file is part of Edgehog.
#
# Copyright 2025-2026 SECO Mind Srl
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

defmodule Edgehog.Campaigns.Channel.Calculations.DeployableDevices do
  @moduledoc """
  Containers calculation to compute valid devices in a channel to receive a deploy.

  It checks devices against the system model of the release.
  """

  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation
  alias Edgehog.Selector

  require Ash.Query

  @impl Calculation
  def load(_query, _opts, _context) do
    [target_groups: [:selector]]
  end

  @impl Calculation
  def calculate(deployment_channels, _opts, context) do
    %{arguments: %{release: release}} = context

    system_model_requirements =
      release
      |> Ash.load!(:system_models)
      |> Map.get(:system_models, [])

    deployment_channels
    |> Ash.load!(target_groups: [:selector])
    |> Enum.map(&resolve_deployment_channel(&1, system_model_requirements, context))
  end

  defp resolve_deployment_channel(deployment_channel, system_model_requirements, context) do
    combined_expr = Enum.reduce(deployment_channel.target_groups, nil, &combine_selectors/2)

    if combined_expr do
      query =
        Edgehog.Devices.Device
        |> Ash.Query.filter(^combined_expr)
        |> Ash.Query.set_tenant(context.tenant)

      query =
        if system_model_requirements != [] do
          system_model_ids = Enum.map(system_model_requirements, & &1.id)
          Ash.Query.filter(query, system_model_part_number.system_model_id in ^system_model_ids)
        else
          query
        end

      Ash.read!(query)
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
