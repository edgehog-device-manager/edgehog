#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule Edgehog.Mocks.Astarte.Device.DeviceStatus do
  @behaviour Edgehog.Astarte.Device.DeviceStatus.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.DeviceStatus
  alias Edgehog.Astarte.InterfaceVersion

  @all_edgehog_interfaces [
    {"io.edgehog.devicemanager.config.Telemetry", 0, 1},
    {"io.edgehog.devicemanager.BaseImage", 0, 1},
    {"io.edgehog.devicemanager.LedBehavior", 0, 1},
    {"io.edgehog.devicemanager.WiFiScanResults", 0, 2},
    {"io.edgehog.devicemanager.OTAEvent", 0, 1},
    {"io.edgehog.devicemanager.Commands", 0, 1},
    {"io.edgehog.devicemanager.CellularConnectionProperties", 0, 1},
    {"io.edgehog.devicemanager.RuntimeInfo", 0, 1},
    {"io.edgehog.devicemanager.HardwareInfo", 0, 1},
    {"io.edgehog.devicemanager.StorageUsage", 0, 1},
    {"io.edgehog.devicemanager.SystemInfo", 0, 1},
    {"io.edgehog.devicemanager.Geolocation", 0, 1},
    {"io.edgehog.devicemanager.CellularConnectionStatus", 0, 1},
    {"io.edgehog.devicemanager.SystemStatus", 0, 1},
    {"io.edgehog.devicemanager.BatteryStatus", 0, 1},
    {"io.edgehog.devicemanager.OTARequest", 1, 0},
    {"io.edgehog.devicemanager.OSInfo", 0, 1},
    {"io.edgehog.devicemanager.NetworkInterfaceProperties", 0, 1}
  ]

  @impl true
  def get(%AppEngine{} = _client, _device_id) do
    introspection =
      for {name, major, minor} <- @all_edgehog_interfaces, into: %{} do
        {name, %InterfaceVersion{major: major, minor: minor}}
      end

    device_status = %DeviceStatus{
      attributes: %{"attribute_key" => "attribute_value"},
      groups: ["test-devices"],
      introspection: introspection,
      last_connection: ~U[2021-11-15 10:44:57.432516Z],
      last_disconnection: ~U[2021-11-15 10:45:57.432516Z],
      last_seen_ip: "198.51.100.25",
      online: false
    }

    {:ok, device_status}
  end
end
