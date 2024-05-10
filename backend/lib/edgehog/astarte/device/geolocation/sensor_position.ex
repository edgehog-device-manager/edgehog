#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.Geolocation.SensorPosition do
  @type t :: %__MODULE__{
          sensor_id: String.t(),
          latitude: float(),
          longitude: float(),
          altitude: float() | nil,
          accuracy: float() | nil,
          altitude_accuracy: float() | nil,
          heading: float() | nil,
          speed: float() | nil,
          timestamp: DateTime.t()
        }

  @enforce_keys [
    :sensor_id,
    :latitude,
    :longitude,
    :altitude,
    :accuracy,
    :altitude_accuracy,
    :heading,
    :speed,
    :timestamp
  ]
  defstruct @enforce_keys
end
