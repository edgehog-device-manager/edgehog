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

defmodule EdgehogWeb.Resolvers.OSManagement do
  alias Edgehog.Devices
  alias Edgehog.OSManagement

  def find_ota_operation(%{id: id}, _resolution) do
    {:ok, OSManagement.get_ota_operation!(id)}
  end

  def ota_operations_for_device(%Devices.Device{} = device, _args, _resolution) do
    {:ok, OSManagement.list_device_ota_operations(device)}
  end

  def create_manual_ota_operation(
        %{device_id: device_id, base_image_file: base_image_file},
        _resolution
      ) do
    device =
      device_id
      |> Devices.get_device!()
      |> Devices.preload_astarte_resources_for_device()

    with {:ok, ota_operation} <- OSManagement.create_manual_ota_operation(device, base_image_file) do
      {:ok, %{ota_operation: ota_operation}}
    end
  end
end
