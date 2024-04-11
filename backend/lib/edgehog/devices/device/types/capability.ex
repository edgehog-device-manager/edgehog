#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Devices.Device.Types.Capability do
  use Ash.Type.Enum,
    values: [
      base_image: "The device provides information about its base image.",
      battery_status: "The device provides information about its battery status.",
      cellular_connection: "The device provides information about its cellular connection.",
      commands: "The device supports commands, for example the rebooting command.",
      geolocation: "The device can be geolocated.",
      hardware_info: "The device provides information about its hardware.",
      led_behaviors: "The device can be asked to blink its LED in a specific pattern.",
      network_interface_info: "The device can provide information about its network interfaces.",
      operating_system: "The device provides information about its operating system.",
      runtime_info: "The device provides information about its runtime.",
      software_updates: "The device can be updated remotely.",
      storage: "The device provides information about its storage units.",
      system_info: "The device provides information about its system.",
      system_status: "The device provides information about its system status.",
      telemetry_config: "The device telemetry can be configured.",
      wifi: "The device provides information about surrounding WiFi APs."
    ]

  def graphql_type(_), do: :device_capability
end
