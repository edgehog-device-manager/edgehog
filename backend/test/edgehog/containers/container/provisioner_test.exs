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
  alias Edgehog.Astarte.Device.CreateContainerRequest
  alias Edgehog.Astarte.Device.CreateContainerRequest.RequestData
  alias Edgehog.Containers.Container.Deployment.Provisioner

  describe "Container deployment provisioner" do
    setup do
      tenant = tenant_fixture()
      deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

      [container_deployment] =
        deployment
        |> Ash.load!([container_deployments: [:container]], tenant: tenant)
        |> Map.get(:container_deployments, [])

      provisioner =
        Provisioner.start_link(
          tenant: tenant,
          container_deployment: container_deployment,
          deployment: deployment,
          mode: :manual
        )

      provisioner =
        case provisioner do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      ref = Process.monitor(provisioner)

      %{
        tenant: tenant,
        deployment: deployment,
        container_deployment: container_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      }
    end

    test "sets-up an container on a device", context do
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

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.start(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end

    test "sets-up an container on a device after a retry", context do
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
        {:error, %Astarte.Client.APIError{status: 500, response: "some error message"}}
      end)
      |> expect(:send_create_container_request, fn _, _, data ->
        assert data == expected_data(container_deployment, deployment)

        container_deployment
        |> Ash.Changeset.for_update(:mark_as_received, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.start(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
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

      Phoenix.PubSub.subscribe(
        Edgehog.PubSub,
        "ready:container_deployments:#{container_deployment.id}"
      )

      Provisioner.start(provisioner)

      assert_receive {:ready, new_container_deployment}, 1000

      assert new_container_deployment.id == container_deployment.id
      assert new_container_deployment.is_ready

      Phoenix.PubSub.unsubscribe(
        Edgehog.PubSub,
        "ready:container_deployments:#{container_deployment.id}"
      )
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

    env_encoding = container.env_encoding
    restart_policy = to_correct_string(container.restart_policy)

    volume_binds = Enum.map(container.container_volumes, & &1.binding)

    binds = volume_binds ++ container.binds

    %RequestData{
      id: container.id,
      deploymentId: deployment.id,
      imageId: image_id,
      volumeIds: volume_ids,
      hostname: container.hostname,
      restartPolicy: restart_policy,
      env: env_encoding,
      binds: binds,
      networkIds: network_ids,
      networkMode: container.network_mode,
      portBindings: container.port_bindings,
      extraHosts: container.extra_hosts,
      capAdd: container.cap_add,
      capDrop: container.cap_drop,
      deviceMappingIds: device_mapping_ids,
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
      privileged: container.privileged
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
end
