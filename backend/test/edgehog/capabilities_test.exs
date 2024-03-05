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

defmodule Edgehog.CapabilitiesTest do
  use ExUnit.Case
  use Edgehog.ForwarderMockCase

  alias Edgehog.Astarte.InterfaceVersion
  alias Edgehog.Capabilities

  describe "from_introspection/1" do
    test "returns all capabilities if interfaces are implemented by the device" do
      device_introspection = %{
        "io.edgehog.devicemanager.BaseImage" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.BatteryStatus" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.CellularConnectionProperties" => %InterfaceVersion{
          major: 0,
          minor: 1
        },
        "io.edgehog.devicemanager.CellularConnectionStatus" => %InterfaceVersion{
          major: 0,
          minor: 1
        },
        "io.edgehog.devicemanager.Commands" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.ForwarderSessionState" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.HardwareInfo" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.LedBehavior" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.NetworkInterfaceProperties" => %InterfaceVersion{
          major: 0,
          minor: 1
        },
        "io.edgehog.devicemanager.OSInfo" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.ForwarderSessionRequest" => %InterfaceVersion{
          major: 0,
          minor: 1
        },
        "io.edgehog.devicemanager.RuntimeInfo" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.OTARequest" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.OTAResponse" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.StorageUsage" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.SystemInfo" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.SystemStatus" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.config.Telemetry" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.WiFiScanResults" => %InterfaceVersion{major: 0, minor: 1}
      }

      expected_capabilities = [
        :base_image,
        :battery_status,
        :cellular_connection,
        :commands,
        :geolocation,
        :hardware_info,
        :led_behaviors,
        :network_interface_info,
        :operating_system,
        :remote_terminal,
        :runtime_info,
        :software_updates,
        :storage,
        :system_info,
        :system_status,
        :telemetry_config,
        :wifi
      ]

      assert Enum.sort(expected_capabilities) ==
               Enum.sort(Capabilities.from_introspection(device_introspection))
    end

    test "returns a capability only if all its interfaces are supported by the device" do
      partial_introspection_1 = %{
        "io.edgehog.devicemanager.OTARequest" => %InterfaceVersion{major: 0, minor: 1}
      }

      partial_introspection_2 = %{
        "io.edgehog.devicemanager.OTAResponse" => %InterfaceVersion{major: 0, minor: 1}
      }

      assert :software_updates not in Capabilities.from_introspection(partial_introspection_1)
      assert :software_updates not in Capabilities.from_introspection(partial_introspection_2)
    end

    test "returns only geolocation if no interface is supported by the device" do
      assert [:geolocation] = Capabilities.from_introspection(%{})
    end

    test "does not fail when devices uses a minor greater than the one required" do
      device_introspection = %{
        "io.edgehog.devicemanager.BatteryStatus" => %InterfaceVersion{major: 0, minor: 2},
        "io.edgehog.devicemanager.CellularConnectionProperties" => %InterfaceVersion{
          major: 0,
          minor: 1
        },
        "io.edgehog.devicemanager.CellularConnectionStatus" => %InterfaceVersion{
          major: 0,
          minor: 3
        }
      }

      expected_capabilities = [
        :battery_status,
        :cellular_connection,
        :geolocation
      ]

      assert Enum.sort(expected_capabilities) ==
               Enum.sort(Capabilities.from_introspection(device_introspection))
    end

    test "does not return a capability if major version mismatches" do
      device_introspection = %{
        "io.edgehog.devicemanager.BatteryStatus" => %InterfaceVersion{major: 1, minor: 0},
        "io.edgehog.devicemanager.CellularConnectionProperties" => %InterfaceVersion{
          major: 1,
          minor: 1
        },
        "io.edgehog.devicemanager.CellularConnectionStatus" => %InterfaceVersion{
          major: 0,
          minor: 1
        }
      }

      assert [:geolocation] = Capabilities.from_introspection(device_introspection)
    end

    test "returns software_updates capability with the older set of interfaces" do
      device_introspection = %{
        "io.edgehog.devicemanager.OTARequest" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.OTAResponse" => %InterfaceVersion{major: 0, minor: 1}
      }

      expected_capabilities = [
        :software_updates,
        :geolocation
      ]

      assert Enum.sort(expected_capabilities) ==
               Enum.sort(Capabilities.from_introspection(device_introspection))
    end

    test "returns software_updates capability with the newer set of interfaces" do
      device_introspection = %{
        "io.edgehog.devicemanager.OTARequest" => %InterfaceVersion{major: 1, minor: 0},
        "io.edgehog.devicemanager.OTAEvent" => %InterfaceVersion{major: 0, minor: 1}
      }

      expected_capabilities = [
        :software_updates,
        :geolocation
      ]

      assert Enum.sort(expected_capabilities) ==
               Enum.sort(Capabilities.from_introspection(device_introspection))
    end

    test "returns remote_terminal capability if the device supports it and the forwarder is enabled" do
      enable_forwarder()

      device_introspection = %{
        "io.edgehog.devicemanager.ForwarderSessionState" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.ForwarderSessionRequest" => %InterfaceVersion{
          major: 0,
          minor: 1
        }
      }

      capabilities = Capabilities.from_introspection(device_introspection)

      assert Enum.member?(capabilities, :remote_terminal)
    end

    test "does not return remote_terminal capability if the device supports it but the forwarder is disabled" do
      disable_forwarder()

      device_introspection = %{
        "io.edgehog.devicemanager.ForwarderSessionState" => %InterfaceVersion{major: 0, minor: 1},
        "io.edgehog.devicemanager.ForwarderSessionRequest" => %InterfaceVersion{
          major: 0,
          minor: 1
        }
      }

      capabilities = Capabilities.from_introspection(device_introspection)

      refute Enum.member?(capabilities, :remote_terminal)
    end

    defp enable_forwarder do
      expect(Edgehog.ForwarderMock, :forwarder_enabled?, fn -> true end)
    end

    defp disable_forwarder do
      expect(Edgehog.ForwarderMock, :forwarder_enabled?, fn -> false end)
    end
  end
end
