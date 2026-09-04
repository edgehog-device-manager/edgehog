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

  alias Edgehog.Astarte.Device.CreateContainerRequest
  alias Edgehog.Astarte.Device.CreateContainerRequest.RequestData

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    device = changeset.data

    with {:ok, deployment} <- Ash.Changeset.fetch_argument(changeset, :deployment),
         {:ok, container} <- Ash.Changeset.fetch_argument(changeset, :container),
         {:ok, container} <-
           Ash.load(container, [
             :env_encoding,
             :image,
             :networks,
             :device_mappings,
             device_requests: [:capabilities],
             container_volumes: [:binding]
           ]),
         {:ok, device} <- Ash.load(device, :appengine_client) do
      env_encoding = container.env_encoding
      restart_policy = to_correct_string(container.restart_policy)

      volume_ids = Enum.map(container.container_volumes, & &1.volume_id)
      volume_binds = Enum.map(container.container_volumes, & &1.binding)

      # Append container binds to volume binds
      binds = volume_binds ++ container.binds

      data = %RequestData{
        id: container.id,
        deploymentId: deployment.id,
        imageId: container.image_id,
        networkIds: Enum.map(container.networks, & &1.id),
        volumeIds: volume_ids,
        deviceMappingIds: Enum.map(container.device_mappings, & &1.id),
        deviceRequestIds: Enum.map(container.device_requests, & &1.id),
        hostname: container.hostname,
        domainname: container.domainname,
        user: container.user,
        cmd: container.command,
        healthcheckTest: container.healthcheck_test,
        healthcheckInterval: container.healthcheck_interval,
        healthcheckTimeout: container.healthcheck_timeout,
        healthcheckRetries: container.healthcheck_retries,
        healthcheckStartPeriod: container.healthcheck_start_period,
        healthcheckStartInterval: container.healthcheck_start_interval,
        workingDir: container.working_directory,
        entrypoint: container.entrypoint,
        networkDisabled: container.network_disabled,
        labelsKeys: container.label_keys,
        labelsValues: container.label_values,
        stopSignal: container.stop_signal,
        stopTimeout: container.stop_timeout,
        restartPolicy: restart_policy,
        restartPolicyMaximumRetryCount: container.restart_policy_maximum_retry_count,
        env: env_encoding,
        binds: binds,
        networkMode: container.network_mode,
        portBindings: container.port_bindings,
        exposedPorts: container.exposed_ports,
        extraHosts: container.extra_hosts,
        capAdd: container.cap_add,
        capDrop: container.cap_drop,
        cpuShares: container.cpu_shares,
        cpusetCpus: container.cpuset_cpus,
        cpuPeriod: normalize(container.cpu_period),
        cpuQuota: normalize(container.cpu_quota),
        cpuRealtimePeriod: normalize(container.cpu_realtime_period),
        cpuRealtimeRuntime: normalize(container.cpu_realtime_runtime),
        memory: normalize(container.memory),
        memoryReservation: normalize(container.memory_reservation),
        memorySwap: normalize_memory_swap(container.memory_swap),
        memorySwappiness: normalize(container.memory_swappiness),
        deviceCgroupRules: container.device_cgroup_rules,
        ulimitsName: container.ulimits_name,
        ulimitsSoft: container.ulimits_soft,
        ulimitsHard: container.ulimits_hard,
        autoRemove: container.auto_remove,
        volumeDriver: container.volume_driver,
        storageOptKeys: container.storage_opt_keys,
        storageOptValues: container.storage_opt_values,
        readOnlyRootfs: container.read_only_rootfs,
        tmpfsPaths: container.tmpfs_paths,
        tmpfsOptions: container.tmpfs_options,
        cgroupnsMode: container.cgroups_mode,
        dns: container.dns,
        dnsOptions: container.dns_options,
        dnsSearch: container.dns_search,
        groupAdd: container.group_add,
        ipcMode: container.ipc_mode,
        oomScoreAdj: container.oom_score_adjustment,
        usernsMode: container.userns_mode,
        sysctlsKeys: container.sysctls_keys,
        sysctlsValues: container.sysctls_values,
        shmSize: container.shm_size,
        runtime: container.runtime,
        privileged: container.privileged,
        logType: container.log_type,
        logConfigKeys: container.log_config_keys,
        logConfigValues: container.log_config_values,
        blkioWeight: container.blkio_weight,
        blkioWeightDevicePath: container.blkio_weight_device_path,
        blkioWeightDeviceWeight: container.blkio_weight_device_weight,
        blkioDeviceReadBpsPath: container.blkio_device_read_bps_path,
        blkioDeviceReadBpsRate: container.blkio_device_read_bps_rate,
        blkioDeviceWriteBpsPath: container.blkio_device_write_bps_path,
        blkioDeviceWriteBpsRate: container.blkio_device_write_bps_rate,
        blkioDeviceReadIopsPath: container.blkio_device_read_iops_path,
        blkioDeviceReadIopsRate: container.blkio_device_read_iops_rate,
        blkioDeviceWriteIopsPath: container.blkio_device_write_iops_path,
        blkioDeviceWriteIopsRate: container.blkio_device_write_iops_rate,
        securityopt: container.securityopt,
        pidMode: container.pid_mode,
        maskedPaths: container.masked_paths,
        readonlyPaths: container.readonly_paths
      }

      with :ok <-
             CreateContainerRequest.send_create_container_request(
               device.appengine_client,
               device.device_id,
               data
             ) do
        {:ok, device}
      end
    end
  end

  defp to_correct_string(atom) do
    atom |> to_string() |> String.replace("_", "-")
  end

  defp normalize(nil), do: -1
  defp normalize(value), do: value
  defp normalize_memory_swap(nil), do: -2
  defp normalize_memory_swap(value), do: value
end
