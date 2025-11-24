#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Reconciler.CoreTest do
  @moduledoc false

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableContainers.ContainerStatus
  alias Edgehog.Astarte.Device.AvailableContainersMock
  alias Edgehog.Astarte.Device.AvailableDeployments.DeploymentStatus
  alias Edgehog.Astarte.Device.AvailableDeploymentsMock
  alias Edgehog.Astarte.Device.AvailableDeviceMappings.DeviceMappingStatus
  alias Edgehog.Astarte.Device.AvailableDeviceMappingsMock
  alias Edgehog.Astarte.Device.AvailableImages.ImageStatus
  alias Edgehog.Astarte.Device.AvailableImagesMock
  alias Edgehog.Astarte.Device.AvailableNetworks.NetworkStatus
  alias Edgehog.Astarte.Device.AvailableNetworksMock
  alias Edgehog.Astarte.Device.AvailableVolumes.VolumeStatus
  alias Edgehog.Astarte.Device.AvailableVolumesMock
  alias Edgehog.Containers.Reconciler

  describe "reconcile_images/2" do
    setup do
      tenant = tenant_fixture()
      deployment = deployment_fixture(release_opts: [containers: 1], tenant: tenant)

      image_deployment =
        deployment
        |> Ash.load!(container_deployments: [:image_deployment])
        |> Map.get(:container_deployments, [])
        |> List.first()
        |> Map.get(:image_deployment)

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        image_deployment: image_deployment,
        device: device
      }
    end

    test "Updates the image state when something's off", %{
      tenant: tenant,
      image_deployment: image_deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableImagesMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%ImageStatus{
              id: image_deployment.image_id,
              pulled: false
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_images(device, tenant)

      new_state =
        image_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :unpulled = new_state
    end

    test "let deployments be when everything's ok", %{
      image_deployment: image_deployment,
      tenant: tenant,
      device: device
    } do
      image_deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :pulled})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableImagesMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%ImageStatus{
              id: image_deployment.image_id,
              pulled: true
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_images(device, tenant)

      new_state =
        image_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :pulled = new_state
    end
  end

  describe "reconcile_volumes/2" do
    setup do
      tenant = tenant_fixture()

      deployment =
        deployment_fixture(
          release_opts: [containers: 1, container_params: [volumes: 1]],
          tenant: tenant
        )

      volume_deployment =
        deployment
        |> Ash.load!(container_deployments: [:volume_deployments])
        |> Map.get(:container_deployments, [])
        |> List.first()
        |> Map.get(:volume_deployments, [])
        |> List.first()

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        volume_deployment: volume_deployment,
        device: device
      }
    end

    test "Updates the volume state when something's off", %{
      tenant: tenant,
      volume_deployment: volume_deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableVolumesMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%VolumeStatus{
              id: volume_deployment.volume_id,
              created: false
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_volumes(device, tenant)

      new_state =
        volume_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :unavailable = new_state
    end

    test "let deployments be when everything's ok", %{
      volume_deployment: volume_deployment,
      tenant: tenant,
      device: device
    } do
      volume_deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :available})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableVolumesMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%VolumeStatus{
              id: volume_deployment.volume_id,
              created: true
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_volumes(device, tenant)

      new_state =
        volume_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :available = new_state
    end
  end

  describe "reconcile_networks/2" do
    setup do
      tenant = tenant_fixture()

      network = network_fixture(tenant: tenant)

      deployment =
        deployment_fixture(
          release_opts: [containers: 1, container_params: [networks: [network.id]]],
          tenant: tenant
        )

      network_deployment =
        deployment
        |> Ash.load!(container_deployments: [:network_deployments])
        |> Map.get(:container_deployments, [])
        |> List.first()
        |> Map.get(:network_deployments, [])
        |> List.first()

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        network_deployment: network_deployment,
        device: device
      }
    end

    test "Updates the network state when something's off", %{
      tenant: tenant,
      network_deployment: network_deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableNetworksMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%NetworkStatus{
              id: network_deployment.network_id,
              created: false
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_networks(device, tenant)

      new_state =
        network_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :unavailable = new_state
    end

    test "let deployments be when everything's ok", %{
      network_deployment: network_deployment,
      tenant: tenant,
      device: device
    } do
      network_deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :available})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableNetworksMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%NetworkStatus{
              id: network_deployment.network_id,
              created: true
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_networks(device, tenant)

      new_state =
        network_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :available = new_state
    end
  end

  describe "reconcile_device_mappings/2" do
    setup do
      tenant = tenant_fixture()

      device_mapping = device_mapping_fixture(tenant: tenant)

      deployment =
        deployment_fixture(
          release_opts: [containers: 1, container_params: [device_mappings: [device_mapping.id]]],
          tenant: tenant
        )

      device_mapping_deployment =
        deployment
        |> Ash.load!(container_deployments: [:device_mapping_deployments])
        |> Map.get(:container_deployments, [])
        |> List.first()
        |> Map.get(:device_mapping_deployments, [])
        |> List.first()

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        device_mapping_deployment: device_mapping_deployment,
        device: device
      }
    end

    test "Updates the device_mapping state when something's off", %{
      tenant: tenant,
      device_mapping_deployment: device_mapping_deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableDeviceMappingsMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%DeviceMappingStatus{
              id: device_mapping_deployment.device_mapping_id,
              present: false
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_device_mappings(device, tenant)

      new_state =
        device_mapping_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :not_present = new_state
    end

    test "let deployments be when everything's ok", %{
      device_mapping_deployment: device_mapping_deployment,
      tenant: tenant,
      device: device
    } do
      device_mapping_deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :present})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableDeviceMappingsMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%DeviceMappingStatus{
              id: device_mapping_deployment.device_mapping_id,
              present: true
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_device_mappings(device, tenant)

      new_state =
        device_mapping_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :present = new_state
    end
  end

  describe "reconcile_containers/2" do
    setup do
      tenant = tenant_fixture()

      deployment =
        deployment_fixture(
          release_opts: [containers: 1],
          tenant: tenant
        )

      container_deployment =
        deployment
        |> Ash.load!(:container_deployments)
        |> Map.get(:container_deployments, [])
        |> List.first()

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        container_deployment: container_deployment,
        device: device
      }
    end

    test "Updates the container state when something's off", %{
      tenant: tenant,
      container_deployment: container_deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableContainersMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%ContainerStatus{
              id: container_deployment.container_id,
              status: "Created"
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_containers(device, tenant)

      new_state =
        container_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :device_created = new_state
    end

    test "let deployments be when everything's ok", %{
      container_deployment: container_deployment,
      tenant: tenant,
      device: device
    } do
      container_deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :device_created})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableContainersMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%ContainerStatus{
              id: container_deployment.container_id,
              status: "Created"
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_containers(device, tenant)

      new_state =
        container_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :device_created = new_state
    end
  end

  describe "reconcile_deployments/2" do
    setup do
      tenant = tenant_fixture()

      deployment =
        deployment_fixture(
          release_opts: [containers: 1],
          tenant: tenant
        )

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        device: device
      }
    end

    test "Updates the deployment state when something's off", %{
      tenant: tenant,
      deployment: deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableDeploymentsMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%DeploymentStatus{
              id: deployment.id,
              status: "Stopped"
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_deployments(device, tenant)

      new_state =
        deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :stopped = new_state
    end

    test "let deployments be when everything's ok", %{
      deployment: deployment,
      tenant: tenant,
      device: device
    } do
      deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :stopped})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableDeploymentsMock, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%DeploymentStatus{
              id: deployment.id,
              status: "Stopped"
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_deployments(device, tenant)

      new_state =
        deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :stopped = new_state
    end
  end

  describe "online_devices/1" do
    setup do
      tenant = tenant_fixture()

      {:ok, %{tenant: tenant}}
    end

    test "list online devices", %{tenant: tenant} do
      device = device_fixture(tenant: tenant, online: true)

      assert {1, stream} = Reconciler.Core.online_devices(tenant)

      read_device =
        stream
        |> Stream.take(1)
        |> Enum.at(0)

      assert device.id == read_device.id
      assert device.device_id == read_device.device_id
    end
  end
end
