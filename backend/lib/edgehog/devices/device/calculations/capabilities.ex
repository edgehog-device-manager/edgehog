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

defmodule Edgehog.Devices.Device.Calculations.Capabilities do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation
  alias Edgehog.Capabilities

  @impl Calculation
  def load(_query, _opts, _context) do
    [:device_status]
  end

  @impl Calculation
  def calculate(devices, _opts, _context) do
    Enum.map(devices, fn
      %{device_status: %{introspection: introspection}} when is_map(introspection) ->
        Capabilities.from_introspection(introspection)

      _ ->
        []
    end)
  end
end
