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

defmodule Edgehog.Devices.Device.Changes.InitializeFromDeviceStatus do
  use Ash.Resource.Change

  @device_status_attributes [:last_connection, :last_disconnection, :online]

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    # After we handle a trigger, we check if any of the fields we can populate from the device
    # status is nil. If there is any, we try to initialize them from the device status.
    Ash.Changeset.after_action(changeset, fn _changeset, device ->
      if uninitialized?(device) do
        device
        |> Ash.load!(:device_status, reuse_values?: true)
        |> initialize_from_status()
      else
        {:ok, device}
      end
    end)
  end

  defp uninitialized?(device) do
    Enum.any?(@device_status_attributes, &(Map.get(device, &1) == nil))
  end

  defp initialize_from_status(%{device_status: nil} = device) do
    # If device status retrieval fails, we just return the device as is. It's going to be
    # retried during the next event.
    {:ok, device}
  end

  defp initialize_from_status(device) do
    attributes = Map.take(device.device_status, @device_status_attributes)

    device
    |> Ash.Changeset.for_update(:from_device_status, attributes)
    |> Ash.update()
  end
end
