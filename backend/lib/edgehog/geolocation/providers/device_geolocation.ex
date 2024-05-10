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

defmodule Edgehog.Geolocation.Providers.DeviceGeolocation do
  @behaviour Edgehog.Geolocation.GeolocationProvider

  alias Edgehog.Astarte.Device.Geolocation.SensorPosition
  alias Edgehog.Devices.Device
  alias Edgehog.Geolocation.Position

  @impl Edgehog.Geolocation.GeolocationProvider
  def geolocate(%Device{} = device) do
    with {:ok, device} <- Ash.load(device, :sensor_positions),
         :ok <- validate_sensor_positions_exist(device.sensor_positions),
         {:ok, sensor_positions} <- filter_latest_sensor_positions(device.sensor_positions) do
      geolocate_sensors(sensor_positions)
    end
  end

  defp validate_sensor_positions_exist(nil), do: {:error, :sensor_positions_not_found}
  defp validate_sensor_positions_exist(_), do: :ok

  defp filter_latest_sensor_positions([_position | _] = sensor_positions) do
    latest_position = Enum.max_by(sensor_positions, & &1.timestamp, DateTime)

    latest_sensor_positions =
      Enum.filter(
        sensor_positions,
        &(DateTime.diff(latest_position.timestamp, &1.timestamp, :second) < 1)
      )

    {:ok, latest_sensor_positions}
  end

  defp filter_latest_sensor_positions(_empty_list) do
    {:error, :sensor_positions_not_found}
  end

  defp geolocate_sensors([%SensorPosition{} | _] = sensor_positions) do
    # Take the position with the accuracy closest to 0. Also note that number < :nil
    sensor_position = Enum.min_by(sensor_positions, & &1.accuracy)

    position = %Position{
      latitude: sensor_position.latitude,
      longitude: sensor_position.longitude,
      altitude: sensor_position.altitude,
      accuracy: sensor_position.accuracy,
      altitude_accuracy: sensor_position.altitude_accuracy,
      heading: sensor_position.heading,
      speed: sensor_position.speed,
      timestamp: sensor_position.timestamp,
      source: """
      Sensor position published by the device on the \
      io.edgehog.devicemanager.Geolocation Astarte interface.\
      """
    }

    {:ok, position}
  end

  defp geolocate_sensors(_empty_list) do
    {:error, :position_not_found}
  end
end
