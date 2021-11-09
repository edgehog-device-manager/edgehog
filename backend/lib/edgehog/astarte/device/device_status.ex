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

defmodule Edgehog.Astarte.Device.DeviceStatus do
  defstruct [
    :last_connection,
    :last_disconnection,
    :online
  ]

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.DeviceStatus

  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_device_status(client, device_id) do
      device_status = %DeviceStatus{
        last_connection: parse_datetime(data["last_connection"]),
        last_disconnection: parse_datetime(data["last_disconnection"]),
        online: data["connected"] || false
      }

      {:ok, device_status}
    end
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
