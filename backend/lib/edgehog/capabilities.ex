#
# This file is part of Edgehog.
#
# Copyright 2022 - 2026 SECO Mind Srl
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

  # This is a keyword list that maps a capability, represented as an atom, to the set of all
  # interfaces that the device must support to claim to support the capability.
  # This needs to be a keyword list because a capability key can appear multiple times, because we
  # could allow its support using different sets of interfaces. This way all devices supporting
  # at least one of the sets will support the capability, and the Astarte context will be
  # responsible of doing the right thing depending on the device introspection (see, for example,
  # software updates)
  @capability_to_required_interfaces [
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
    container_management: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.AvailableContainers",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.AvailableDeployments",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.AvailableImages",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.AvailableNetworks",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.AvailableVolumes",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.CreateContainerRequest",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.CreateDeploymentRequest",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.CreateImageRequest",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.CreateNetworkRequest",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.CreateVolumeRequest",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.DeploymentCommand",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.DeploymentEvent",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.apps.DeploymentUpdate",
        major: 0,
        minor: 1
      }
    ],
    file_transfer_stream: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.fileTransfer.posix.ServerToDevice",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.fileTransfer.Progress",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.fileTransfer.Response",
        major: 0,
        minor: 1
      }
    ],
    file_transfer_storage: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.fileTransfer.posix.ServerToDevice",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.fileTransfer.Progress",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.fileTransfer.Response",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.storage.File",
        major: 0,
        minor: 1
      }
    ],
    file_transfer_read: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.fileTransfer.DeviceToServer",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.fileTransfer.Progress",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.fileTransfer.Response",
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
    remote_terminal: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.ForwarderSessionRequest",
        major: 0,
        minor: 1
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.ForwarderSessionState",
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
    software_updates: [
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.OTARequest",
        major: 1,
        minor: 0
      },
      %Astarte.InterfaceID{
        name: "io.edgehog.devicemanager.OTAEvent",
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
  ]

  @doc """
  Returns a `MapSet` of atoms representing the capabilities supported by a device, given its
  introspection as input.
  """
  def from_introspection(introspection) when is_map(introspection) do
    capabilities =
      Enum.reduce(@capability_to_required_interfaces, MapSet.new(), fn
        {capability, interface_list}, acc ->
          if Enum.all?(interface_list, &interface_supported?(introspection, &1)) do
            MapSet.put(acc, capability)
          else
            acc
          end
      end)

    # TODO add checks on device privacy settings and geolocation providers
    capabilities
    |> MapSet.put(:geolocation)
    |> MapSet.to_list()
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
