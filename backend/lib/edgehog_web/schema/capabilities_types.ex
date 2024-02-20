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

defmodule EdgehogWeb.Schema.CapabilitiesTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  @desc """
  The capabilities that devices can support
  """
  enum :device_capability do
    @desc "The device provides information about its base image."
    value :base_image
    @desc "The device provides information about its battery status."
    value :battery_status
    @desc "The device provides information about its cellular connection."
    value :cellular_connection
    @desc "The device supports commands, for example the rebooting command."
    value :commands
    @desc "The device can be geolocated."
    value :remote_terminal
    @desc "The device supports remote terminal sessions."
    value :geolocation
    @desc "The device provides information about its hardware."
    value :hardware_info
    @desc "The device can be asked to blink its LED in a specific pattern."
    value :led_behaviors
    @desc "The device can provide information about its network interfaces."
    value :network_interface_info
    @desc "The device provides information about its operating system."
    value :operating_system
    @desc "The device provides information about its runtime."
    value :runtime_info
    @desc "The device can be updated remotely."
    value :software_updates
    @desc "The device provides information about its storage units."
    value :storage
    @desc "The device provides information about its system."
    value :system_info
    @desc "The device provides information about its system status."
    value :system_status
    @desc "The device telemetry can be configured."
    value :telemetry_config
    @desc "The device provides information about surrounding WiFi APs."
    value :wifi
  end
end
