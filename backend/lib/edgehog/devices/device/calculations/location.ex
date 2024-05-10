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

defmodule Edgehog.Devices.Device.Calculations.Location do
  use Ash.Resource.Calculation

  alias Edgehog.Geolocation

  @impl true
  def load(_query, _opts, _context) do
    [:position]
  end

  @impl true
  def calculate(devices, _opts, _context) do
    Enum.map(devices, &get_location(&1.position))
  end

  defp get_location(nil), do: nil

  defp get_location(position) do
    case Geolocation.reverse_geocode(position) do
      {:ok, location} -> location
      _ -> nil
    end
  end
end
