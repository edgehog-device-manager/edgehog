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
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.FileTransferCapabilities.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.FileTransferCapabilities

  @type target :: :storage | :streaming | :filesystem

  @type t :: %__MODULE__{
          encodings: [String.t()],
          unix_permissions: boolean() | nil,
          targets: [target()]
        }

  @enforce_keys [:encodings, :unix_permissions, :targets]
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
    %FileTransferCapabilities{
      encodings: Map.get(data, "encodings", []),
      unix_permissions: Map.get(data, "unixPermissions"),
      targets: parse_targets(Map.get(data, "targets", []))
    }
  end

  defp parse_targets(targets) when is_list(targets) do
    targets
    |> Enum.map(&parse_target/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_targets(_), do: []

  defp parse_target("storage"), do: :storage
  defp parse_target("streaming"), do: :streaming
  defp parse_target("filesystem"), do: :filesystem
  defp parse_target(:storage), do: :storage
  defp parse_target(:streaming), do: :streaming
  defp parse_target(:filesystem), do: :filesystem
  defp parse_target(_), do: nil
end
