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
  import Absinthe.Resolution.Helpers

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
      |> Resolvers.Devices.preload_localized_system_model(context)

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

  @doc """
  Resolve the list of groups for a device, batching it for all devices.

  This allows retrieving the list for all devices by doing one query for the device list and one
  query for each of the groups (so it's independent from the number of devices).
  """
  def batched_groups_for_device(device, _args, %{context: context}) do
    # We have to pass the tenant_id to the batch function since it gets executed in a separate process
    tenant_id = context.current_tenant.tenant_id

    batch({__MODULE__, :device_groups_by_device_id, tenant_id}, device.id, fn batch_results ->
      {:ok, Map.get(batch_results, device.id)}
    end)
  end

  def device_groups_by_device_id(tenant_id, device_ids) do
    # Use the correct tenant_id in the batching process
    Edgehog.Repo.put_tenant_id(tenant_id)

    Groups.get_groups_for_device_ids(device_ids)
  end
end
