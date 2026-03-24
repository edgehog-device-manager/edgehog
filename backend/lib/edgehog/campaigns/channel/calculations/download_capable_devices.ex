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

  require Ash.Query

  @impl Ash.Resource.Calculation
  def calculate(channels, _opts, _context) do
    channels
    |> Ash.load!(target_groups: [:devices])
    |> Enum.map(fn channel ->
      channel.target_groups
      |> Enum.flat_map(& &1.devices)
      |> Enum.uniq_by(& &1.id)
    end)
  end
end
