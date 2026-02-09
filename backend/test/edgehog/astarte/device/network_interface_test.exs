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

defmodule Edgehog.Astarte.Device.NetworkInterfaceTest do
  use ExUnit.Case, async: true

  alias Edgehog.Astarte.Device.NetworkInterface

  describe "parse_data/1" do
    test "correctly parses NetworkInterface data" do
      data = %{
        "enp2s0" => %{
          "macAddress" => "00:aa:bb:cc:dd:ee",
          "technologyType" => "Ethernet"
        },
        "wlp3s0" => %{
          "macAddress" => "00:aa:bb:cc:dd:ff",
          "technologyType" => "WiFi"
        }
      }

      assert [
               %NetworkInterface{
                 name: "enp2s0",
                 mac_address: "00:aa:bb:cc:dd:ee",
                 technology: "Ethernet"
               },
               %NetworkInterface{
                 name: "wlp3s0",
                 mac_address: "00:aa:bb:cc:dd:ff",
                 technology: "WiFi"
               }
             ] == NetworkInterface.parse_data(data)
    end
  end
end
