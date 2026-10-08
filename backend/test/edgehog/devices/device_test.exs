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

defmodule Edgehog.Devices.DeviceTest do
  @moduledoc false

  use Edgehog.DataCase, async: false

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.DeviceMapping
  alias Edgehog.Containers.DeviceRequest
  alias Edgehog.Containers.EnvFile
  alias Edgehog.Containers.FileBind
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Volume
  alias Edgehog.Devices.Device

  require Ash.Query

  describe "destroying a device" do
    setup do
      tenant = tenant_fixture()

      image = image_fixture(tenant: tenant)
      network = network_fixture(tenant: tenant)
      device_mapping = device_mapping_fixture(tenant: tenant)
      device_request = device_request_fixture(tenant: tenant)

      container =
        container_fixture(
          tenant: tenant,
          image: image,
          volumes: 1,
          networks: [network],
          device_mappings: [device_mapping],
          device_requests: [device_request]
        )

      %{
        tenant: tenant,
        image: image,
        network: network,
        device_mapping: device_mapping,
        device_request: device_request,
        container: container
      }
    end

    test "successfully deletes all related deployment records also", context do
      %{tenant: tenant, container: container} = context

      device = device_fixture(tenant: tenant)

      release = release_fixture(tenant: tenant, container_ids: [container.id])

      deployment =
        deployment_fixture(tenant: tenant, device_id: device.id, release_id: release.id)

      deployment = Ash.load!(deployment, [:container_deployments], tenant: tenant)
      [container_deployment] = deployment.container_deployments

      file_mount = file_mount_fixture(tenant: tenant, container_id: container.id, required: false)

      file_bind =
        file_bind_fixture(
          tenant: tenant,
          container_deployment_id: container_deployment.id,
          device_id: device.id,
          file_mount_id: file_mount.id
        )

      {:ok, env_file} =
        EnvFile
        |> Ash.Changeset.for_create(
          :create,
          %{
            container_deployment_id: container_deployment.id,
            device_id: device.id,
            file_name: "config.env"
          },
          tenant: tenant
        )
        |> Ash.create()

      container_deployment =
        Ash.load!(
          container_deployment,
          [
            :image_deployment,
            :volume_deployments,
            :network_deployments,
            :device_mapping_deployments,
            :device_request_deployments
          ],
          tenant: tenant
        )

      image_deployment = container_deployment.image_deployment
      [volume_deployment] = container_deployment.volume_deployments
      [network_deployment] = container_deployment.network_deployments
      [device_mapping_deployment] = container_deployment.device_mapping_deployments
      [device_request_deployment] = container_deployment.device_request_deployments

      # Verify all records exist prior to deletion
      assert entry_exists?(Device, device.id, tenant)
      assert entry_exists?(Deployment, deployment.id, tenant)
      assert entry_exists?(Container.Deployment, container_deployment.id, tenant)
      assert entry_exists?(Image.Deployment, image_deployment.id, tenant)
      assert entry_exists?(Network.Deployment, network_deployment.id, tenant)
      assert entry_exists?(Volume.Deployment, volume_deployment.id, tenant)
      assert entry_exists?(DeviceMapping.Deployment, device_mapping_deployment.id, tenant)
      assert entry_exists?(DeviceRequest.Deployment, device_request_deployment.id, tenant)
      assert entry_exists?(FileBind, file_bind.id, tenant)
      assert entry_exists?(EnvFile, env_file.id, tenant)

      # Destroy the device
      assert :ok = Ash.destroy(device)

      # Verify device and all dependent records are deleted
      refute entry_exists?(Device, device.id, tenant)
      refute entry_exists?(Deployment, deployment.id, tenant)
      refute entry_exists?(Container.Deployment, container_deployment.id, tenant)
      refute entry_exists?(Image.Deployment, image_deployment.id, tenant)
      refute entry_exists?(Network.Deployment, network_deployment.id, tenant)
      refute entry_exists?(Volume.Deployment, volume_deployment.id, tenant)
      refute entry_exists?(DeviceMapping.Deployment, device_mapping_deployment.id, tenant)
      refute entry_exists?(DeviceRequest.Deployment, device_request_deployment.id, tenant)
      refute entry_exists?(FileBind, file_bind.id, tenant)
      refute entry_exists?(EnvFile, env_file.id, tenant)
    end
  end

  defp entry_exists?(resource, id, tenant) do
    resource
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.set_tenant(tenant)
    |> Ash.exists?()
  end
end
