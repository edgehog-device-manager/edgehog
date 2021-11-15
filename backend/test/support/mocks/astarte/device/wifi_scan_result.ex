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

defmodule Edgehog.Mocks.Astarte.Device.WiFiScanResult do
  @behaviour Edgehog.Astarte.Device.WiFiScanResult.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.WiFiScanResult

  @impl true
  def get(%AppEngine{} = _client, _device_id) do
    wifi_scan_results = [
      %WiFiScanResult{
        channel: 11,
        essid: nil,
        mac_address: "01:23:45:67:89:ab",
        rssi: -43,
        timestamp: ~U[2021-11-15 11:44:57.432516Z]
      }
    ]

    {:ok, wifi_scan_results}
  end
end
