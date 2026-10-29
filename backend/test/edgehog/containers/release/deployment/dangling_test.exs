#
# This file is part of Edgehog.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Edgehog.Containers.DeploymentTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.DeviceMapping
  alias Edgehog.Containers.DeviceRequest
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Volume

  setup do
    tenant = tenant_fixture()
    deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

    %{tenant: tenant, deployment: deployment}
  end

  test "destroy_if_dangling removes the container_deployment only if danlging", %{
    deployment: deployment
  } do
    deployment = Ash.load!(deployment, :container_deployments)
    [container_deployment] = deployment.container_deployments

    assert {:error, _} =
             container_deployment
             |> Ash.Changeset.for_destroy(:destroy_if_dangling)
             |> Ash.destroy()

    Ash.destroy!(deployment)

    assert :ok = Ash.destroy(container_deployment)
  end

  test "destroy_and_gc garbage collects", %{
    deployment: deployment
  } do
    deployment =
      Ash.load!(deployment,
        container_deployments: [
          :image_deployment,
          :volume_deployments,
          :network_deployments,
          :device_mapping_deployments,
          :device_request_deployments
        ]
      )

    [container_deployment] = deployment.container_deployments
    image_deployment = container_deployment.image_deployment

    deployment
    |> Ash.Changeset.for_destroy(:destroy_and_gc)
    |> Ash.destroy!()

    assert {:error, _} = Ash.get(Image.Deployment, image_deployment.id)
    assert {:error, _} = Ash.get(Container.Deployment, container_deployment.id)
    assert {:error, _} = Ash.get(Release, deployment.release_id)
    assert {:error, _} = Ash.get(Container, container_deployment.container_id)
    assert {:error, _} = Ash.get(Image, image_deployment.image_id)
  end

  test "deploy deep-copies resources, keeps originals in plain_*, and allows editing plain resources",
       %{tenant: tenant} do
    plain_image = image_fixture(tenant: tenant)
    plain_volume = volume_fixture(tenant: tenant, driver: "local", options: %{"o" => "1"})
    plain_network = network_fixture(tenant: tenant, driver: "bridge")
    plain_dm = device_mapping_fixture(tenant: tenant)
    plain_dr = device_request_fixture(tenant: tenant)

    plain_container =
      container_fixture(
        tenant: tenant,
        image: plain_image,
        volumes: [{plain_volume, "/mnt/vol"}],
        networks: [plain_network],
        device_mappings: [plain_dm],
        device_requests: [plain_dr],
        file_mounts: [%{mountpoint: "/etc/config.txt", required: false}]
      )

    plain_release =
      release_fixture(
        tenant: tenant,
        container_ids: [plain_container.id],
        version: "1.0.0"
      )

    device = device_fixture(tenant: tenant)

    deployment =
      [
        tenant: tenant,
        device_id: device.id,
        release_id: plain_release.id
      ]
      |> deployment_fixture()
      |> Ash.load!(
        [
          :release,
          container_deployments: [
            container: [
              :image,
              :volumes,
              :networks,
              :device_mappings,
              :device_requests,
              :file_mounts
            ]
          ]
        ],
        tenant: tenant
      )

    deployed_release = deployment.release
    [container_deployment] = deployment.container_deployments
    deployed_container = container_deployment.container
    [deployed_volume] = deployed_container.volumes
    [deployed_network] = deployed_container.networks
    [deployed_dm] = deployed_container.device_mappings
    [deployed_dr] = deployed_container.device_requests
    [deployed_fm] = deployed_container.file_mounts

    assert deployed_release.id != plain_release.id
    assert deployed_release.version == plain_release.version
    assert deployed_container.id != plain_container.id
    assert deployed_container.name == plain_container.name
    assert deployed_container.image.id != plain_image.id
    assert deployed_container.image.reference == plain_image.reference
    assert deployed_volume.id != plain_volume.id
    assert deployed_volume.label == plain_volume.label
    assert deployed_network.id != plain_network.id
    assert deployed_network.label == plain_network.label
    assert deployed_dm.id != plain_dm.id
    assert deployed_dm.path_in_container == plain_dm.path_in_container
    assert deployed_dr.id != plain_dr.id
    assert deployed_dr.driver == plain_dr.driver
    assert deployed_fm.mountpoint == "/etc/config.txt"

    # Plain read actions only include the original un-deployed resources, while deployed_* only include copies
    plain_release_ids =
      Release
      |> Ash.Query.for_read(:plain_releases, %{}, tenant: tenant)
      |> Ash.read!()
      |> Enum.map(& &1.id)

    deployed_release_ids =
      Release
      |> Ash.Query.for_read(:deployed_releases, %{}, tenant: tenant)
      |> Ash.read!()
      |> Enum.map(& &1.id)

    assert plain_release.id in plain_release_ids
    refute deployed_release.id in plain_release_ids
    assert deployed_release.id in deployed_release_ids
    refute plain_release.id in deployed_release_ids

    plain_container_ids =
      Container
      |> Ash.Query.for_read(:plain_containers, %{}, tenant: tenant)
      |> Ash.read!()
      |> Enum.map(& &1.id)

    deployed_container_ids =
      Container
      |> Ash.Query.for_read(:deployed_containers, %{}, tenant: tenant)
      |> Ash.read!()
      |> Enum.map(& &1.id)

    assert plain_container.id in plain_container_ids
    refute deployed_container.id in plain_container_ids
    assert deployed_container.id in deployed_container_ids
    refute plain_container.id in deployed_container_ids

    # Editing the plain volume does not mutate the deployed volume copy
    updated_plain_volume =
      plain_volume
      |> Ash.Changeset.for_update(:update, %{driver: "nfs", options: %{"o" => "2"}},
        tenant: tenant
      )
      |> Ash.update!(tenant: tenant)

    assert updated_plain_volume.driver == "nfs"
    reloaded_deployed_volume = Ash.get!(Volume, deployed_volume.id, tenant: tenant)
    assert reloaded_deployed_volume.driver == "local"
    assert reloaded_deployed_volume.options == %{"o" => "1"}

    # Destroying the deployment garbage-collects all copied resources while keeping plain resources
    deployment
    |> Ash.Changeset.for_destroy(:destroy_and_gc, %{}, tenant: tenant)
    |> Ash.destroy!(tenant: tenant)

    assert {:error, _} = Ash.get(Release, deployed_release.id, tenant: tenant)
    assert {:error, _} = Ash.get(Container, deployed_container.id, tenant: tenant)
    assert {:error, _} = Ash.get(Image, deployed_container.image.id, tenant: tenant)
    assert {:error, _} = Ash.get(Volume, deployed_volume.id, tenant: tenant)
    assert {:error, _} = Ash.get(Network, deployed_network.id, tenant: tenant)
    assert {:error, _} = Ash.get(DeviceMapping, deployed_dm.id, tenant: tenant)
    assert {:error, _} = Ash.get(DeviceRequest, deployed_dr.id, tenant: tenant)

    assert {:ok, _} = Ash.get(Release, plain_release.id, tenant: tenant)
    assert {:ok, _} = Ash.get(Container, plain_container.id, tenant: tenant)
    assert {:ok, _} = Ash.get(Image, plain_image.id, tenant: tenant)
    assert {:ok, _} = Ash.get(Volume, plain_volume.id, tenant: tenant)
    assert {:ok, _} = Ash.get(Network, plain_network.id, tenant: tenant)
  end

  test "shared volume and network across containers are preserved if only one container is destroyed",
       %{tenant: tenant} do
    shared_volume = volume_fixture(tenant: tenant)
    shared_network = network_fixture(tenant: tenant)

    c1 =
      container_fixture(
        tenant: tenant,
        volumes: [{shared_volume, "/mnt/shared1"}],
        networks: [shared_network]
      )

    c2 =
      container_fixture(
        tenant: tenant,
        volumes: [{shared_volume, "/mnt/shared2"}],
        networks: [shared_network]
      )

    release = release_fixture(tenant: tenant, container_ids: [c1.id, c2.id])
    device = device_fixture(tenant: tenant)

    deployment =
      [tenant: tenant, device_id: device.id, release_id: release.id]
      |> deployment_fixture()
      |> Ash.load!([:release, container_deployments: [container: [:volumes, :networks]]],
        tenant: tenant
      )

    [cd1, cd2] = deployment.container_deployments
    [vol1] = cd1.container.volumes
    [vol2] = cd2.container.volumes
    [net1] = cd1.container.networks
    [net2] = cd2.container.networks

    # Both containers in the release share the same copied volume and network
    assert vol1.id == vol2.id
    assert vol1.id != shared_volume.id
    assert net1.id == net2.id
    assert net1.id != shared_network.id

    # If the release is destroyed and only one container deployment is destroyed and GC'd,
    # the shared volume and network are preserved because the second container still references them
    Ash.destroy!(deployment, tenant: tenant)
    Ash.destroy!(deployment.release, tenant: tenant)

    cd1
    |> Ash.Changeset.for_destroy(:destroy_if_dangling, %{}, tenant: tenant)
    |> Ash.destroy!(tenant: tenant)

    Ash.destroy!(cd1.container, tenant: tenant)

    assert {:error, _} = Ash.get(Container, cd1.container_id, tenant: tenant)
    assert {:ok, _} = Ash.get(Volume, vol1.id, tenant: tenant)
    assert {:ok, _} = Ash.get(Network, net1.id, tenant: tenant)
  end

  test "reuses unchanged volume, network, and image across release deployments on the same device and preserves them on GC",
       %{tenant: tenant} do
    application = application_fixture(tenant: tenant)
    plain_image = image_fixture(tenant: tenant)
    plain_volume = volume_fixture(tenant: tenant, driver: "local", options: %{"o" => "1"})
    plain_network = network_fixture(tenant: tenant, driver: "bridge", internal: false)

    c1 =
      container_fixture(
        tenant: tenant,
        image: plain_image,
        volumes: [{plain_volume, "/data"}],
        networks: [plain_network]
      )

    c2 =
      container_fixture(
        tenant: tenant,
        image: plain_image,
        volumes: [{plain_volume, "/data"}],
        networks: [plain_network]
      )

    release_v1 =
      release_fixture(
        tenant: tenant,
        application_id: application.id,
        version: "1.0.0",
        container_ids: [c1.id]
      )

    release_v2 =
      release_fixture(
        tenant: tenant,
        application_id: application.id,
        version: "2.0.0",
        container_ids: [c2.id]
      )

    device = device_fixture(tenant: tenant)

    dep_v1 =
      [tenant: tenant, device_id: device.id, release_id: release_v1.id]
      |> deployment_fixture()
      |> Ash.load!(
        [
          container_deployments: [
            :image_deployment,
            :volume_deployments,
            :network_deployments
          ]
        ],
        tenant: tenant
      )

    dep_v2 =
      [tenant: tenant, device_id: device.id, release_id: release_v2.id]
      |> deployment_fixture()
      |> Ash.load!(
        [
          container_deployments: [
            :image_deployment,
            :volume_deployments,
            :network_deployments
          ]
        ],
        tenant: tenant
      )

    [cd_v1] = dep_v1.container_deployments
    [cd_v2] = dep_v2.container_deployments
    [vd_v1] = cd_v1.volume_deployments
    [vd_v2] = cd_v2.volume_deployments
    [net_dep_v1] = cd_v1.network_deployments
    [net_dep_v2] = cd_v2.network_deployments

    assert cd_v1.image_deployment.id == cd_v2.image_deployment.id
    assert vd_v1.id == vd_v2.id
    assert net_dep_v1.id == net_dep_v2.id

    # Destroying v1 preserves the shared volume, network, and image deployments used by v2
    dep_v1
    |> Ash.Changeset.for_destroy(:destroy_and_gc, %{}, tenant: tenant)
    |> Ash.destroy!(tenant: tenant)

    assert {:ok, _} = Ash.get(Volume.Deployment, vd_v2.id, tenant: tenant)
    assert {:ok, _} = Ash.get(Volume, vd_v2.volume_id, tenant: tenant)
    assert {:ok, _} = Ash.get(Network.Deployment, net_dep_v2.id, tenant: tenant)
    assert {:ok, _} = Ash.get(Network, net_dep_v2.network_id, tenant: tenant)
    assert {:ok, _} = Ash.get(Image.Deployment, cd_v2.image_deployment.id, tenant: tenant)
    assert {:ok, _} = Ash.get(Image, cd_v2.image_deployment.image_id, tenant: tenant)

    # Editing plain_volume before deploying v3 creates a distinct Volume.Deployment for v3
    plain_volume
    |> Ash.Changeset.for_update(:update, %{driver: "nfs", options: %{"o" => "2"}}, tenant: tenant)
    |> Ash.update!(tenant: tenant)

    release_v3 =
      release_fixture(
        tenant: tenant,
        application_id: application.id,
        version: "3.0.0",
        container_ids: [c2.id]
      )

    dep_v3 =
      [tenant: tenant, device_id: device.id, release_id: release_v3.id]
      |> deployment_fixture()
      |> Ash.load!([container_deployments: [:volume_deployments, :network_deployments]],
        tenant: tenant
      )

    [cd_v3] = dep_v3.container_deployments
    [vd_v3] = cd_v3.volume_deployments
    [net_dep_v3] = cd_v3.network_deployments

    assert vd_v3.id != vd_v2.id
    assert net_dep_v3.id == net_dep_v2.id
  end
end
