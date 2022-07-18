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

defmodule Edgehog.Geolocation.Providers.DeviceGeolocation do
  @behaviour Edgehog.Geolocation.GeolocationProvider

  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device.Geolocation.SensorPosition
  alias Edgehog.Devices
  alias Edgehog.Devices.Device
  alias Edgehog.Geolocation.Position

  @impl Edgehog.Geolocation.GeolocationProvider
  def geolocate(%Device{device_id: device_id} = device) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, sensors_positions} <- Astarte.fetch_geolocation(client, device_id),
         {:ok, sensors_positions} <- filter_latest_sensors_positions(sensors_positions) do
      geolocate_sensors(sensors_positions)
    end
  end

  defp filter_latest_sensors_positions([_position | _] = sensors_positions) do
    latest_position = Enum.max_by(sensors_positions, & &1.timestamp, DateTime)

    latest_sensors_positions =
      Enum.filter(
        sensors_positions,
        &(DateTime.diff(latest_position.timestamp, &1.timestamp, :second) < 1)
      )

    {:ok, latest_sensors_positions}
  end

  defp filter_latest_sensors_positions(_empty_list) do
    {:error, :sensors_positions_not_found}
  end

  defp geolocate_sensors([%SensorPosition{} | _] = sensors_positions) do
    # Take the position with the accuracy closest to 0. Also note that number < :nil
    sensor_position = Enum.min_by(sensors_positions, & &1.accuracy)

    position = %Position{
      latitude: sensor_position.latitude,
      longitude: sensor_position.longitude,
      accuracy: sensor_position.accuracy,
      timestamp: sensor_position.timestamp
    }

    {:ok, position}
  end

  defp geolocate_sensors(_empty_list) do
    {:error, :position_not_found}
  end
end
