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

defmodule Edgehog.Devices.Device.ManualActions.SendVolumeCommand do
  @moduledoc false
  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.VolumeCommand
  alias Edgehog.Astarte.Device.VolumeCommand.RequestData
  alias Edgehog.Containers

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    command = changeset.arguments.command
    volume = changeset.arguments.volume
    device = changeset.data

    with {:ok, command} <- volume_command_from_enum(command),
         {:ok, _deployment} <-
           Containers.fetch_volume_deployment(volume.id, device.id, tenant: device.tenant_id),
         {:ok, device} <- Ash.load(device, :appengine_client),
         data = %RequestData{volume_id: volume.id, command: command},
         :ok <-
           VolumeCommand.send_volume_command(
             device.appengine_client,
             device.device_id,
             data
           ) do
      {:ok, device}
    end
  end

  defp volume_command_from_enum(command) do
    case command do
      :delete -> {:ok, "Delete"}
      _ -> {:error, "Unknown volume command"}
    end
  end
end
