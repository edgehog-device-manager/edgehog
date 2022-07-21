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

defmodule EdgehogWeb.Resolvers.Groups do
  alias Edgehog.Groups
  alias Edgehog.Groups.DeviceGroup
  alias EdgehogWeb.Resolvers

  @doc """
  Finds the device group by id
  """
  def find_device_group(%{id: id}, _resolution) do
    Groups.fetch_device_group(id)
  end

  @doc """
  Lists all device groups
  """
  def list_device_groups(_args, _resolution) do
    {:ok, Groups.list_device_groups()}
  end

  @doc """
  Lists all devices in a device group
  """
  def devices_for_group(%DeviceGroup{} = device_group, _args, %{context: context} = _resolution) do
    devices =
      Groups.list_devices_in_group(device_group)
      |> Resolvers.Devices.preload_system_model_for_device(context)

    {:ok, devices}
  end

  @doc """
  Creates a device group
  """
  def create_device_group(attrs, _resolution) do
    with {:ok, device_group} <- Groups.create_device_group(attrs) do
      {:ok, %{device_group: device_group}}
    end
  end

  @doc """
  Updates a device group
  """
  def update_device_group(%{device_group_id: id} = attrs, _resolution) do
    with {:ok, device_group} <- Groups.fetch_device_group(id),
         {:ok, device_group} <- Groups.update_device_group(device_group, attrs) do
      {:ok, %{device_group: device_group}}
    end
  end

  @doc """
  Deletes a device group
  """
  def delete_device_group(%{device_group_id: id}, _resolution) do
    with {:ok, device_group} <- Groups.fetch_device_group(id),
         {:ok, device_group} <- Groups.delete_device_group(device_group) do
      {:ok, %{device_group: device_group}}
    end
  end
end
