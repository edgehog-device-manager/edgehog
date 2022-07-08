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

defmodule Edgehog.Capabilities do
  @moduledoc """
  The Capabilities context.
  """

  alias Edgehog.Astarte

  @introspection_capability_map %{
    base_image: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.BaseImage",
        major: 0,
        minor: 1
      }
    ],
    battery_status: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.BatteryStatus",
        major: 0,
        minor: 1
      }
    ],
    cellular_connection: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.CellularConnectionProperties",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.CellularConnectionStatus",
        major: 0,
        minor: 1
      }
    ],
    commands: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.Commands",
        major: 0,
        minor: 1
      }
    ],
    hardware_info: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.HardwareInfo",
        major: 0,
        minor: 1
      }
    ],
    led_behaviors: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.LedBehavior",
        major: 0,
        minor: 1
      }
    ],
    network_interface_info: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.NetworkInterfaceProperties",
        major: 0,
        minor: 1
      }
    ],
    operating_system: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.OSInfo",
        major: 0,
        minor: 1
      }
    ],
    runtime_info: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.RuntimeInfo",
        major: 0,
        minor: 1
      }
    ],
    software_updates: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.OTARequest",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.OTAResponse",
        major: 0,
        minor: 1
      }
    ],
    storage: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.StorageUsage",
        major: 0,
        minor: 1
      }
    ],
    system_info: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.SystemInfo",
        major: 0,
        minor: 1
      }
    ],
    system_status: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.SystemStatus",
        major: 0,
        minor: 1
      }
    ],
    telemetry_config: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.config.Telemetry",
        major: 0,
        minor: 1
      }
    ],
    wifi: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.WiFiScanResults",
        major: 0,
        minor: 1
      }
    ]
  }

  def from_introspection(introspection) when is_map(introspection) do
    capabilities =
      Enum.reduce(@introspection_capability_map, [], fn {capability, interface_list}, acc ->
        if Enum.all?(interface_list, &interface_supported?(introspection, &1)) do
          [capability | acc]
        else
          acc
        end
      end)

    # TODO add checks on device privacy settings and geolocation providers
    [:geolocation | capabilities]
  end

  defp interface_supported?(introspection, %Astarte.InterfaceID{} = interface) do
    case Map.fetch(introspection, interface.name) do
      {:ok, %Astarte.InterfaceVersion{major: major, minor: minor}} ->
        major == interface.major && minor >= interface.minor

      _ ->
        false
    end
  end
end
