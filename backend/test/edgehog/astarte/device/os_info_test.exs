#
# This file is part of Edgehog.
#
# Copyright 2021 - 2026 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.OSInfoTest do
  use ExUnit.Case, async: true

  alias Edgehog.Astarte.Device.OSInfo

  describe "parse_os_info/1" do
    test "correctly parses OS info data" do
      data = %{
        "osName" => "esp-idf",
        "osVersion" => "v4.3.1"
      }

      assert %OSInfo{
               name: "esp-idf",
               version: "v4.3.1"
             } == OSInfo.parse_data(data)
    end
  end
end
