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

defmodule Edgehog.Mocks.Geolocation.GeolocationProvider do
  @behaviour Edgehog.Geolocation.GeolocationProvider

  alias Edgehog.Geolocation.Position

  @impl true
  def geolocate(_device) do
    coordinates = %Position{
      latitude: 45.4095285,
      longitude: 11.8788231,
      accuracy: 12,
      altitude: nil,
      altitude_accuracy: nil,
      heading: nil,
      speed: nil,
      timestamp: ~U[2021-11-15 11:44:57.432516Z]
    }

    {:ok, coordinates}
  end
end
