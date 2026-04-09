#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.FileTransferCapabilitiesTest do
  use ExUnit.Case, async: true

  alias Edgehog.Astarte.Device.FileTransferCapabilities

  describe "parse_data/1" do
    test "correctly parses file transfer capabilities" do
      data = %{
        "encodings" => ["gz", "tar.gz"],
        "unixPermissions" => true,
        "targets" => ["storage", "streaming"]
      }

      assert %FileTransferCapabilities{
               encodings: ["gz", "tar.gz"],
               unix_permissions: true,
               targets: [:storage, :streaming]
             } == FileTransferCapabilities.parse_data(data)
    end

    test "uses defaults for missing array values" do
      data = %{"unixPermissions" => false}

      assert %FileTransferCapabilities{
               encodings: [],
               unix_permissions: false,
               targets: []
             } == FileTransferCapabilities.parse_data(data)
    end

    test "ignores unsupported targets" do
      data = %{"targets" => ["storage", "invalid", "filesystem"]}

      parsed = FileTransferCapabilities.parse_data(data)

      assert parsed.targets == [:storage, :filesystem]
    end
  end
end
