#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.BatteryStatus do
  @behaviour Edgehog.Astarte.Device.BatteryStatus.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.BatteryStatus.BatterySlot

  @interface "io.edgehog.devicemanager.BatteryStatus"

  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface, query: [limit: 1]) do
      battery_slots =
        data
        |> Enum.map(fn
          {label, [battery_slot]} -> parse_battery_slot(label, battery_slot)
          # TODO: handle value as single object too, as a workaround for the issue:
          # https://github.com/astarte-platform/astarte/issues/707
          {label, battery_slot} -> parse_battery_slot(label, battery_slot)
        end)

      {:ok, battery_slots}
    end
  end

  defp parse_battery_slot(slot_label, battery_slot) when is_binary(slot_label) do
    %BatterySlot{
      slot: slot_label,
      level_percentage: battery_slot["levelPercentage"],
      level_absolute_error: battery_slot["levelAbsoluteError"],
      status: battery_slot["status"]
    }
  end
end
