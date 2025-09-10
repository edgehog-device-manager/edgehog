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

defmodule Edgehog.Campaigns.Channel.Calculations.DeployableDevices do
  @moduledoc """
  Containers calculation to compute valid devices in a channel to receive a deploy.

  It checks devices against the system model of the release.
  """

  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @impl Calculation
  def load(_query, _opts, _context) do
    [target_groups: [devices: :system_model]]
  end

  @impl Calculation
  def calculate(deployment_channels, _opts, context) do
    %{arguments: %{release: release}} = context

    system_model_ids =
      release
      |> Ash.load!(:system_models)
      |> Map.get(:system_models, [])
      |> Enum.map(& &1.id)

    Enum.map(deployment_channels, fn deployment_channel ->
      deployment_channel.target_groups
      |> Enum.flat_map(fn target_group ->
        Enum.filter(
          target_group.devices,
          &(&1.system_model != nil && &1.system_model.id in system_model_ids)
        )
      end)
      |> Enum.uniq_by(& &1.id)
    end)
  end
end
