#
# This file is part of Edgehog.
#
# Copyright 2021,2022 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.WiFiScanResult do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.WiFiScanResult.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.WiFiScanResult

  @enforce_keys [:timestamp]
  defstruct [
    :channel,
    :connected,
    :essid,
    :mac_address,
    :rssi,
    :timestamp
  ]

  @type t() :: %__MODULE__{
          channel: integer() | nil,
          connected: boolean() | nil,
          essid: String.t() | nil,
          mac_address: String.t() | nil,
          rssi: integer() | nil,
          timestamp: DateTime.t()
        }

  @interface "io.edgehog.devicemanager.WiFiScanResults"

  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface, query: [limit: 1000]) do
      wifi_scan_results =
        data
        |> Map.get("ap", [])
        |> Enum.map(fn ap ->
          %WiFiScanResult{
            channel: ap["channel"],
            connected: ap["connected"],
            essid: ap["essid"],
            mac_address: ap["macAddress"],
            rssi: ap["rssi"],
            timestamp: parse_datetime(ap["timestamp"])
          }
        end)

      {:ok, wifi_scan_results}
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
