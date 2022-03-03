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

defmodule Edgehog.Astarte.Device.Geolocation do
  @behaviour Edgehog.Astarte.Device.Geolocation.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.Geolocation.SensorPosition

  @interface "io.edgehog.devicemanager.Geolocation"

  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface, limit: 1),
         {:ok, sensors_positions} <- parse_data(data) do
      {:ok, sensors_positions}
    end
  end

  def parse_data(data) do
    sensors_positions =
      data
      |> Enum.map(fn {sensor_id, [sensor_data]} ->
        %SensorPosition{
          sensor_id: sensor_id,
          latitude: sensor_data["latitude"],
          longitude: sensor_data["longitude"],
          altitude: sensor_data["altitude"],
          accuracy: sensor_data["accuracy"],
          altitude_accuracy: sensor_data["altitudeAccuracy"],
          heading: sensor_data["heading"],
          speed: sensor_data["speed"],
          timestamp: parse_datetime(sensor_data["timestamp"])
        }
      end)

    {:ok, sensors_positions}
  end

  defp parse_datetime(nil) do
    nil
  end

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end
end
