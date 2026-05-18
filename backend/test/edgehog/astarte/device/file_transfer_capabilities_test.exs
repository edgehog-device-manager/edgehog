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
    test "correctly parses file transfer capabilities with all fields" do
      data = %{
        "transfer" => %{
          "unixPermissions" => true,
          "serverToDevice" => %{
            "targets" => ["storage", "streaming"]
          },
          "deviceToServer" => %{
            "targets" => ["filesystem"]
          }
        },
        "serverToDevice" => %{
          "storage" => %{"encodings" => ["gz", "tar.gz"]},
          "streaming" => %{"encodings" => ["lz4"]}
        },
        "deviceToServer" => %{
          "filesystem" => %{"encodings" => ["tar", "tar.lz4"]}
        }
      }

      result = FileTransferCapabilities.parse_data(data)

      assert result.unix_permissions == true

      assert result.server_to_device == %{
               storage: ["gz", "tar.gz"],
               streaming: ["lz4"],
               filesystem: nil
             }

      assert result.device_to_server == %{
               storage: nil,
               streaming: nil,
               filesystem: ["tar", "tar.lz4"]
             }
    end

    test "uses defaults for missing values" do
      data = %{"transfer" => %{"unixPermissions" => false}}

      result = FileTransferCapabilities.parse_data(data)

      assert result.unix_permissions == false

      assert result.server_to_device == %{
               storage: nil,
               streaming: nil,
               filesystem: nil
             }

      assert result.device_to_server == %{
               storage: nil,
               streaming: nil,
               filesystem: nil
             }
    end

    test "handles missing transfer section" do
      data = %{}

      result = FileTransferCapabilities.parse_data(data)

      assert result.unix_permissions == nil

      assert result.server_to_device == %{
               storage: nil,
               streaming: nil,
               filesystem: nil
             }

      assert result.device_to_server == %{
               storage: nil,
               streaming: nil,
               filesystem: nil
             }
    end

    test "ignores unsupported targets" do
      data = %{
        "transfer" => %{
          "unixPermissions" => true,
          "serverToDevice" => %{
            "targets" => ["storage", "invalid", "filesystem"]
          }
        }
      }

      result = FileTransferCapabilities.parse_data(data)

      assert result.server_to_device == %{
               storage: [],
               streaming: nil,
               filesystem: []
             }
    end

    test "handles missing encodings for targets" do
      data = %{
        "transfer" => %{
          "serverToDevice" => %{
            "targets" => ["storage"]
          }
        },
        "serverToDevice" => %{
          "storage" => %{"encodings" => []},
          "streaming" => %{}
        }
      }

      result = FileTransferCapabilities.parse_data(data)

      assert result.server_to_device == %{
               storage: [],
               streaming: nil,
               filesystem: nil
             }

      assert result.device_to_server == %{
               storage: nil,
               streaming: nil,
               filesystem: nil
             }
    end
  end
end
