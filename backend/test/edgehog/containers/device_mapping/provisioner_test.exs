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

defmodule Edgehog.Containers.DeviceMapping.Deployment.ProvisionerTest do
  @moduledoc """
  Tests for the device_mapping deployment provisioner.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Astarte.Device.AvailableDeviceMappings
  alias Edgehog.Astarte.Device.AvailableDeviceMappings.DeviceMappingStatus
  alias Edgehog.Astarte.Device.CreateDeviceMappingRequest
  alias Edgehog.Config
  alias Edgehog.Containers.DeviceMapping.Deployment.Provisioner

  describe "DeviceMapping deployment provisioner" do
    setup do
      tenant = tenant_fixture()
      device_mapping = device_mapping_fixture(tenant: tenant)

      deployment =
        deployment_fixture(
          tenant: tenant,
          release_opts: [containers: 1, container_params: [device_mappings: [device_mapping.id]]]
        )

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

      [device_mapping_deployments] =
        deployment
        |> Ash.load!(
          [container_deployments: [device_mapping_deployments: [:device_mapping, :device]]],
          tenant: tenant
        )
        |> Map.get(:container_deployments, [])
        |> Enum.map(&Map.get(&1, :device_mapping_deployments))

      [device_mapping_deployment] = device_mapping_deployments

      provisioner =
        Provisioner.start(
          tenant: tenant,
          device_mapping_deployment: device_mapping_deployment,
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
        device_mapping_deployment: device_mapping_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      }
    end

    test "sets-up a device mapping on a device", context do
      %{
        device_mapping_deployment: device_mapping_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateDeviceMappingRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_device_mapping_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateDeviceMappingRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          pathOnHost: path_on_host,
          pathInContainer: path_in_container,
          cGroupPermissions: c_group_permissisons
        } = data

        assert id == device_mapping_deployment.device_mapping.id
        assert deployment_id == deployment.id
        assert path_on_host == device_mapping_deployment.device_mapping.path_on_host
        assert path_in_container == device_mapping_deployment.device_mapping.path_in_container
        assert c_group_permissisons == device_mapping_deployment.device_mapping.cgroup_permissions

        # Update the device_mapping deployment to be ready

        device_mapping_deployment
        |> Ash.Changeset.for_update(:mark_as_present, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end

    test "sets-up a device mapping on a device after a retry", context do
      %{
        device_mapping_deployment: device_mapping_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateDeviceMappingRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_device_mapping_request, fn _, _, _ ->
        {:error, %Astarte.Client.APIError{status: 500, response: "some error message"}}
      end)
      |> expect(:send_create_device_mapping_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateDeviceMappingRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          pathOnHost: path_on_host,
          pathInContainer: path_in_container,
          cGroupPermissions: c_group_permissisons
        } = data

        assert id == device_mapping_deployment.device_mapping.id
        assert deployment_id == deployment.id
        assert path_on_host == device_mapping_deployment.device_mapping.path_on_host
        assert path_in_container == device_mapping_deployment.device_mapping.path_in_container
        assert c_group_permissisons == device_mapping_deployment.device_mapping.cgroup_permissions

        device_mapping_deployment
        |> Ash.Changeset.for_update(:mark_as_present, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 2000
    end

    test "emits :ready on correct topic on provisioning completion", context do
      %{
        device_mapping_deployment: device_mapping_deployment,
        deployment: deployment,
        provisioner: provisioner,
        tenant: tenant
      } = context

      test_process = self()

      CreateDeviceMappingRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_device_mapping_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateDeviceMappingRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          pathOnHost: path_on_host,
          pathInContainer: path_in_container,
          cGroupPermissions: c_group_permissisons
        } = data

        assert id == device_mapping_deployment.device_mapping.id
        assert deployment_id == deployment.id
        assert path_on_host == device_mapping_deployment.device_mapping.path_on_host
        assert path_in_container == device_mapping_deployment.device_mapping.path_in_container
        assert c_group_permissisons == device_mapping_deployment.device_mapping.cgroup_permissions

        device_mapping_deployment
        |> Ash.Changeset.for_update(:mark_as_present, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Phoenix.PubSub.subscribe(
        Edgehog.PubSub,
        "ready:device_mapping_deployments:#{device_mapping_deployment.id}"
      )

      Provisioner.run(provisioner)

      assert_receive {:ready, new_device_mapping_deployment}, 1000

      assert new_device_mapping_deployment.id == device_mapping_deployment.id
      assert new_device_mapping_deployment.is_ready

      Phoenix.PubSub.unsubscribe(
        Edgehog.PubSub,
        "ready:device_mapping_deployments:#{device_mapping_deployment.id}"
      )
    end

    test "doesn't send deployment if it's ready", context do
      %{
        device_mapping_deployment: device_mapping_deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateDeviceMappingRequest
      |> allow(test_process, provisioner)
      |> reject(:send_create_device_mapping_request, 3)

      Sandbox.allow(Edgehog.Repo, test_process, provisioner)

      ready_topic = "ready:device_mapping_deployments:#{device_mapping_deployment.id}"
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      device_mapping_deployment =
        device_mapping_deployment
        |> Ash.Changeset.for_update(:mark_as_present, %{})
        |> Ash.update!(tenant: tenant)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
      assert_receive {:ready, new_device_mapping_deployment}, 1000

      assert new_device_mapping_deployment.id == device_mapping_deployment.id
      assert new_device_mapping_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, ready_topic)
    end

    test "reconciles the state with astarte if a timeout on send is found", context do
      %{
        device_mapping_deployment: device_mapping_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      } = context

      test_process = self()

      # Remove the Pan
      Config
      |> allow(test_process, provisioner)
      |> stub(:message_min_timeout!, fn -> 0 end)

      CreateDeviceMappingRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_device_mapping_request, fn _, _, _ ->
        :ok
      end)

      device_id = device_mapping_deployment.device.device_id

      AvailableDeviceMappings
      |> allow(test_process, provisioner)
      |> expect(:get, fn _client, ^device_id ->
        device_mappings = [
          %DeviceMappingStatus{id: device_mapping_deployment.device_mapping.id, present: false}
        ]

        {:ok, device_mappings}
      end)

      ready_topic = "ready:device_mapping_deployments:#{device_mapping_deployment.id}"
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 3000
      assert_receive {:ready, new_device_mapping_deployment}, 1000

      assert new_device_mapping_deployment.id == device_mapping_deployment.id
      assert new_device_mapping_deployment.is_ready

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

      CreateDeviceMappingRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_device_mapping_request, fn _, _, _ -> :ok end)

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

      CreateDeviceMappingRequest
      |> allow(test_process, provisioner)
      |> reject(:send_create_device_mapping_request, 3)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :device_offline}}, 2000
    end
  end

  defp now, do: DateTime.now!("Etc/UTC")
end
