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

defmodule Edgehog.Astarte.Device.RuntimeInfoTest do
  use ExUnit.Case

  alias Edgehog.Astarte.Device.RuntimeInfo

  @moduletag :ported_to_ash

  describe "parse_data/1" do
    test "correctly parses RuntimeInfo data" do
      data = %{
        "name" => "edgehog-esp32-device",
        "version" => "0.1.0",
        "environment" => "esp-idf v4.3",
        "url" => "https://github.com/edgehog-device-manager/edgehog-esp32-device"
      }

      assert %RuntimeInfo{
               name: data["name"],
               version: data["version"],
               environment: data["environment"],
               url: data["url"]
             } == RuntimeInfo.parse_data(data)
    end
  end
end
