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

defmodule Edgehog.Astarte.Device.BatteryStatus do
  @behaviour Edgehog.Astarte.Device.BatteryStatus.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.BatteryStatus.BatterySlot

  @interface "io.edgehog.devicemanager.BatteryStatus"

  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface) do
      battery_status =
        Enum.map(data, fn {slot,
                           %{
                             "levelPercentage" => level_percentage,
                             "levelAbsoluteError" => level_absolute_error,
                             "status" => status
                           }} ->
          %BatterySlot{
            slot: slot,
            level_percentage: level_percentage,
            level_absolute_error: level_absolute_error,
            status: status
          }
        end)

      {:ok, battery_status}
    end
  end
end
