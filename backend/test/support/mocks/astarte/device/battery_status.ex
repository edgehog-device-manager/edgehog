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

defmodule Edgehog.Mocks.Astarte.Device.BatteryStatus do
  @behaviour Edgehog.Astarte.Device.BatteryStatus.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.BatteryStatus.BatterySlot

  @impl true
  def get(%AppEngine{} = _client, _device_id) do
    battery_status = [
      %BatterySlot{
        slot: "Slot name",
        level_percentage: 80.3,
        level_absolute_error: 0.1,
        status: "Charging"
      }
    ]

    {:ok, battery_status}
  end
end
