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

defmodule Edgehog.Containers.Container.Deployment.ProvisionerTest do
  @moduledoc """
  Tests for the container deployment provisioner.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Astarte.Device.AvailableContainers
  alias Edgehog.Astarte.Device.AvailableContainers.ContainerStatus
  alias Edgehog.Astarte.Device.CreateContainerRequest
  alias Edgehog.Astarte.Device.CreateContainerRequest.RequestData
  alias Edgehog.Config
  alias Edgehog.Containers.Container.Deployment.Provisioner

  describe "Container deployment provisioner" do
    setup do
      tenant = tenant_fixture()
      deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

      timestamp = now()

      opts = %{
        online: true,
        last_connection: timestamp,
        last_disconnection: timestamp
      }

      deployment =
        deployment
        |> Map.get(:device)
        |> Ash.Changeset.for_update(:from_device_status, opts)
        |> Ash.update!(tenant: tenant)
        |> then(&Map.put(deployment, :device, &1))

      [container_deployment] =
        deployment
        |> Ash.load!([container_deployments: [:container, :device]], tenant: tenant)
        |> Map.get(:container_deployments, [])

      provisioner =
        Provisioner.start(
          tenant: tenant,
          resource: container_deployment,
          deployment: deployment,
          mode: :manual
        )

      provisioner =
        case provisioner do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      ref = Process.monitor(provisioner)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      %{
        tenant: tenant,
        deployment: deployment,
        container_deployment: container_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      }
    end

    test "sets-up a container on a device", context do
      %{
        container_deployment: container_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateContainerRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_container_request, fn _, _, data ->
        assert data == expected_data(container_deployment, deployment)

        # Update the container deployment to be ready

        container_deployment
        |> Ash.Changeset.for_update(:mark_as_received, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end

    test "sets-up a container on a device after a retry", context do
      %{
        container_deployment: container_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateContainerRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_container_request, fn _, _, _ ->
        {:error, %Edgehog.Error.AstarteAPIError{status: 500, response: "some error message"}}
      end)
      |> expect(:send_create_container_request, fn _, _, data ->
        assert data == expected_data(container_deployment, deployment)

        container_deployment
        |> Ash.Changeset.for_update(:mark_as_received, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 2000
    end

    test "emits :ready on correct topic on provisioning completion", context do
      %{
        container_deployment: container_deployment,
        deployment: deployment,
        provisioner: provisioner,
        tenant: tenant
      } = context

      test_process = self()

      CreateContainerRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_container_request, fn _, _, data ->
        assert data == expected_data(container_deployment, deployment)

        container_deployment
        |> Ash.Changeset.for_update(:mark_as_received, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      topic = Provisioner.Core.topic(container_deployment)

      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      Provisioner.run(provisioner)

      assert_receive {:ready, new_container_deployment}, 2000

      assert new_container_deployment.id == container_deployment.id
      assert new_container_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end

    test "doesn't send deployment if it's ready", context do
      %{
        container_deployment: container_deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateContainerRequest
      |> allow(test_process, provisioner)
      |> reject(:send_create_container_request, 3)

      Sandbox.allow(Edgehog.Repo, test_process, provisioner)

      ready_topic = Provisioner.Core.topic(container_deployment.id)
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      container_deployment =
        container_deployment
        |> Ash.Changeset.for_update(:mark_as_received, %{})
        |> Ash.update!(tenant: tenant)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
      assert_receive {:ready, new_container_deployment}, 1000

      assert new_container_deployment.id == container_deployment.id
      assert new_container_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, ready_topic)
    end

    test "reconciles the state with astarte if a timeout on send is found", context do
      %{
        container_deployment: container_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      } = context

      test_process = self()

      # Remove the Pan
      Config
      |> allow(test_process, provisioner)
      |> stub(:message_min_timeout!, fn -> 0 end)

      CreateContainerRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_container_request, fn _, _, _ ->
        :ok
      end)

      device_id = container_deployment.device.device_id

      AvailableContainers
      |> allow(test_process, provisioner)
      |> expect(:get, fn _client, ^device_id ->
        containers = [
          %ContainerStatus{id: container_deployment.container.id, status: "Created"}
        ]

        {:ok, containers}
      end)

      ready_topic = Provisioner.Core.topic(container_deployment)
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 3000
      assert_receive {:ready, new_container_deployment}, 3000

      assert new_container_deployment.id == container_deployment.id
      assert new_container_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, ready_topic)
    end

    test "stops if device goes offline", context do
      %{
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      timestamp = now()

      CreateContainerRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_container_request, fn _, _, _ -> :ok end)

      Sandbox.allow(Edgehog.Repo, test_process, provisioner)
      Provisioner.run(provisioner)

      opts = %{
        online: false,
        last_connection: timestamp,
        last_disconnection: timestamp
      }

      device =
        deployment
        |> Map.get(:device)
        |> Ash.Changeset.for_update(:from_device_status, opts)
        |> Ash.update!(tenant: tenant)

      refute device.online
      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :device_offline}}, 2000
    end

    test "immediately stops if device is offline at startup", context do
      %{
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      timestamp = now()

      opts = %{
        online: false,
        last_connection: timestamp,
        last_disconnection: timestamp
      }

      device =
        deployment
        |> Map.get(:device)
        |> Ash.Changeset.for_update(:from_device_status, opts)
        |> Ash.update!(tenant: tenant)

      refute device.online

      test_process = self()

      Sandbox.allow(Edgehog.Repo, test_process, provisioner)

      CreateContainerRequest
      |> allow(test_process, provisioner)
      |> reject(:send_create_container_request, 3)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :device_offline}}, 2000
    end

    test "stops on unsolvable, non-temporary errors", context do
      %{
        container_deployment: container_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      } = context

      test_process = self()

      topic = Provisioner.Core.topic(container_deployment)

      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      CreateContainerRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_container_request, fn _, _, _ ->
        {:error, %Edgehog.Error.AstarteAPIError{status: 400, response: "some error message"}}
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :unsolvable_api_error}},
                     2000

      assert_receive {:failure, failed_resource}, 2000
      assert failed_resource.id == container_deployment.id

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end
  end

  # TODO: Logic copied from `send_create_container.ex`, maybe extrapolate this
  # into a function call &( to_request_data :: container -> request_data )
  defp expected_data(container_deployment, deployment) do
    container_deployment =
      Ash.load!(container_deployment,
        container: [
          :env_encoding,
          :image,
          :networks,
          :volumes,
          :device_mappings,
          :device_requests,
          container_volumes: [:binding]
        ]
      )

    image_id = container_deployment.container.image.id
    container = container_deployment.container

    volume_ids =
      container
      |> Map.get(:volumes, [])
      |> Enum.map(& &1.volume.id)

    network_ids =
      container
      |> Map.get(:networks, [])
      |> Enum.map(& &1.id)

    device_mapping_ids =
      container
      |> Map.get(:device_mappings, [])
      |> Enum.map(& &1.id)

    device_request_ids =
      container
      |> Map.get(:device_requests, [])
      |> Enum.map(& &1.id)

    env_encoding = container.env_encoding
    restart_policy = to_correct_string(container.restart_policy)

    volume_binds = Enum.map(container.container_volumes, & &1.binding)

    binds = volume_binds ++ container.binds

    %RequestData{
      id: container.id,
      deploymentId: deployment.id,
      imageId: image_id,
      networkIds: network_ids,
      volumeIds: volume_ids,
      deviceMappingIds: device_mapping_ids,
      deviceRequestIds: device_request_ids,
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
  end

  defp to_correct_string(atom) do
    atom
    |> to_string()
    |> String.replace("_", "-")
  end

  defp normalize(nil), do: -1
  defp normalize(value), do: value
  defp normalize_memory_swap(nil), do: -2
  defp normalize_memory_swap(value), do: value

  defp now, do: DateTime.now!("Etc/UTC")
end
