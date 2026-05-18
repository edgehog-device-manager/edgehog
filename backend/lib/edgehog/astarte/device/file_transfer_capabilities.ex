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

defmodule Edgehog.Astarte.Device.FileTransferCapabilities do
  @moduledoc """
  This module defines the `FileTransferCapabilities` struct and implements the
  `Edgehog.Astarte.Device.FileTransferCapabilities.Behaviour` to fetch and parse
  file transfer capabilities from an Astarte device.

  Capabilities are split into global configuration and direction-specific capabilities
  (`server_to_device` and `device_to_server`).

  The incoming Astarte properties data payload contains:
  * A `transfer` map containing global settings like `unixPermissions` and lists of supported
    `targets` for each direction.
  * Root-level maps for each direction (e.g., `serverToDevice`, `deviceToServer`) containing
    the specific configurations—such as supported compressed `encodings`—for each target type.

  ### Parsing Rules

  For each known target (`:storage`, `:streaming`, `:filesystem`), the parser applies the
  following logic based on the device configuration:

  1. Supported with Encodings: If a target string is present within the direction's `targets`
     array, and a corresponding root encoding list exists, it returns the list of encodings
     (e.g., `["tar.gz"]`).
  2. Supported without Encodings: If a target string is present within the direction's `targets`
     array but no encoding property is set on the device, it returns an empty list (`[]`).
  3. Unsupported: If a target string is entirely absent from the direction's `targets` array,
     it returns `nil`.
  """
  @behaviour Edgehog.Astarte.Device.FileTransferCapabilities.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.FileTransferCapabilities

  @type t :: %__MODULE__{
          unix_permissions: boolean() | nil,
          server_to_device: capabilities(),
          device_to_server: capabilities()
        }

  @type target :: :storage | :streaming | :filesystem
  @type target_capability :: nil | [String.t()]

  @type capabilities :: %{
          optional(target()) => target_capability()
        }

  @enforce_keys [
    :unix_permissions,
    :server_to_device,
    :device_to_server
  ]

  defstruct @enforce_keys

  @interface "io.edgehog.devicemanager.fileTransfer.Capabilities"

  @impl Edgehog.Astarte.Device.FileTransferCapabilities.Behaviour
  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_properties_data(client, device_id, @interface) do
      {:ok, parse_data(data)}
    end
  end

  def parse_data(data) do
    transfer_data = Map.get(data, "transfer", %{})

    server_to_device_targets = get_in(transfer_data, ["serverToDevice", "targets"]) || []
    device_to_server_targets = get_in(transfer_data, ["deviceToServer", "targets"]) || []

    server_to_device_encodings = Map.get(data, "serverToDevice", %{})
    device_to_server_encodings = Map.get(data, "deviceToServer", %{})

    %FileTransferCapabilities{
      unix_permissions: Map.get(transfer_data, "unixPermissions"),
      server_to_device:
        parse_direction_capabilities(server_to_device_targets, server_to_device_encodings),
      device_to_server:
        parse_direction_capabilities(device_to_server_targets, device_to_server_encodings)
    }
  end

  defp parse_direction_capabilities(targets, encodings_data) do
    targets_to_check = [
      {"storage", :storage},
      {"streaming", :streaming},
      {"filesystem", :filesystem}
    ]

    Enum.reduce(targets_to_check, %{}, fn {str_key, atom_key}, acc ->
      if str_key in targets do
        # If it is part of targets, check for encodings
        Map.put(acc, atom_key, extract_encodings(encodings_data, str_key))
      else
        # If it is not part of targets, it should be nil
        Map.put(acc, atom_key, nil)
      end
    end)
  end

  defp extract_encodings(encodings_data, str_key) do
    case Map.get(encodings_data, str_key) do
      %{"encodings" => list} when is_list(list) -> list
      # If it doesn't have encodings, return an empty list
      _ -> []
    end
  end
end
