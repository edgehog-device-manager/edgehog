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

defmodule Edgehog.Devices.Device.Calculations.SensorPositions do
  use Ash.Resource.Calculation

  @geolocation_module Application.compile_env(
                        :edgehog,
                        :astarte_geolocation_module,
                        Edgehog.Astarte.Device.Geolocation
                      )

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context) do
    [:device_id, :appengine_client]
  end

  @impl Ash.Resource.Calculation
  def calculate(devices, _opts, _context) do
    Enum.map(devices, fn device ->
      %{
        device_id: device_id,
        appengine_client: appengine_client
      } = device

      list_sensor_positions(appengine_client, device_id)
    end)
  end

  defp list_sensor_positions(appengine_client, device_id) do
    case @geolocation_module.get(appengine_client, device_id) do
      {:ok, sensor_positions} -> sensor_positions
      {:error, _reason} -> []
    end
  end
end
