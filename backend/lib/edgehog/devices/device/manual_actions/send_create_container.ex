#
# This file is part of Edgehog.
#
# Copyright 2024 - 2026 SECO Mind Srl
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

defmodule Edgehog.Devices.Device.ManualActions.SendCreateContainer do
  @moduledoc false
  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.CreateBind
  alias Edgehog.Astarte.Device.CreateBind.RequestData, as: BindRequestData
  alias Edgehog.Astarte.Device.CreateContainerRequest
  alias Edgehog.Astarte.Device.CreateContainerRequest.RequestData
  alias Edgehog.Containers.Container.Env

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    device = changeset.data

    with {:ok, deployment} <- Ash.Changeset.fetch_argument(changeset, :deployment),
         {:ok, container_deployment} <-
           Ash.Changeset.fetch_argument(changeset, :container_deployment),
         {:ok, container_deployment} <-
           Ash.load(container_deployment, [:container, :file_binds]),
         {:ok, container} <- Map.fetch(container_deployment, :container),
         {:ok, container} <-
           Ash.load(container, [
             :image,
             :networks,
             :device_mappings,
             device_requests: [:capabilities],
             container_volumes: [:binding]
           ]),
         {:ok, device} <- Ash.load(device, :appengine_client) do
      restart_policy = to_correct_string(container.restart_policy)

      volume_ids = Enum.map(container.container_volumes, & &1.volume_id)
      volume_binds = Enum.map(container.container_volumes, & &1.binding)

      # Append container binds to volume binds
      binds = volume_binds ++ container.binds

      binds_request = build_binds_request(container_deployment.file_binds)

      data = %RequestData{
        id: container.id,
        deploymentId: deployment.id,
        imageId: container.image_id,
        volumeIds: volume_ids,
        hostname: container.hostname,
        restartPolicy: restart_policy,
        env: Env.encode(container_deployment.env),
        binds: binds,
        networkIds: Enum.map(container.networks, & &1.id),
        networkMode: container.network_mode,
        portBindings: container.port_bindings,
        extraHosts: container.extra_hosts,
        capAdd: container.cap_add,
        capDrop: container.cap_drop,
        deviceMappingIds: Enum.map(container.device_mappings, & &1.id),
        fileBindIds: Enum.map(container_deployment.file_binds, & &1.id),
        cpuPeriod: normalize(container.cpu_period),
        cpuQuota: normalize(container.cpu_quota),
        cpuRealtimePeriod: normalize(container.cpu_realtime_period),
        cpuRealtimeRuntime: normalize(container.cpu_realtime_runtime),
        memory: normalize(container.memory),
        memoryReservation: normalize(container.memory_reservation),
        memorySwap: normalize_memory_swap(container.memory_swap),
        memorySwappiness: normalize(container.memory_swappiness),
        volumeDriver: container.volume_driver,
        storageOpt: container.storage_opt,
        readOnlyRootfs: container.read_only_rootfs,
        tmpfs: container.tmpfs,
        privileged: container.privileged,
        deviceRequestIds: Enum.map(container.device_requests, & &1.id)
      }

      with :ok <- send_binds(binds_request, device),
           :ok <-
             CreateContainerRequest.send_create_container_request(
               device.appengine_client,
               device.device_id,
               data
             ) do
        {:ok, device}
      end
    end
  end

  defp build_binds_request(file_binds) do
    Enum.map(file_binds, fn file_bind ->
      file_bind = Ash.load!(file_bind, file_mount: :mountpoint)

      %BindRequestData{
        id: file_bind.id,
        targetId: bind_target_id(file_bind),
        targetType: bind_target_type(file_bind),
        mountpoint: file_bind.file_mount.mountpoint,
        options: ""
      }
    end)
  end

  defp send_binds([], _device), do: :ok

  defp send_binds(binds, device) do
    Enum.reduce_while(binds, :ok, fn bind, :ok ->
      case CreateBind.send_bind(device.appengine_client, device.device_id, bind) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp bind_target_id(%{file_download_request_id: id} = file_bind) do
    id || file_bind.device_file_id
  end

  defp bind_target_type(%{device_file_id: device_file_id}) when is_nil(device_file_id),
    do: "request"

  defp bind_target_type(_file_bind), do: "storage"

  defp to_correct_string(atom) do
    atom |> to_string() |> String.replace("_", "-")
  end

  defp normalize(nil), do: -1
  defp normalize(value), do: value
  defp normalize_memory_swap(nil), do: -2
  defp normalize_memory_swap(value), do: value
end
