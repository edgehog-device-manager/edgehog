#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Mocks.Astarte.Device.Geolocation do
  @behaviour Edgehog.Astarte.Device.Geolocation.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.Geolocation.SensorPosition

  @impl true
  def get(%AppEngine{} = _client, _device_id) do
    sensors_positions = [
      %SensorPosition{
        sensor_id: "gps1",
        latitude: 45.4095285,
        longitude: 11.8788231,
        altitude: nil,
        accuracy: 0.0,
        altitude_accuracy: nil,
        heading: nil,
        speed: nil,
        timestamp: ~U[2021-11-30 10:45:00.575Z]
      }
    ]

    {:ok, sensors_positions}
  end
end
