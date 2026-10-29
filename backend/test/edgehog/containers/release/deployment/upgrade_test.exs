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

defmodule Edgehog.Containers.Release.Deployment.UpgradeTest do
  @moduledoc """
  Tests for upgrading a deployment to a newer release.

  These tests exercise the upgrade path (`upgrade_release` action) and
  specifically the `ReadyAction.create_deployment` action used to
  create the new deployment. The new deployment must be created without
  starting a deployment supervisor inside the upgrade transaction: the
  supervisor is started by an `after_transaction` hook, so it can only read
  the (now committed) underlying container deployments.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers.Release.Deployment
  alias Edgehog.Containers.Release.Deployment.ReadyAction

  require Ash.Query

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "upgrade_release" do
    test "starts a supervisor for the new deployment after the data is committed", %{
      tenant: tenant
    } do
      deployment = ready_deployment_fixture(tenant: tenant)

      target_release =
        [
          tenant: tenant,
          application_id: deployment.release.application_id,
          version: "0.0.2",
          containers: 1
        ]
        |> release_fixture()
        |> Ash.load!(:containers, tenant: tenant)

      parent = self()
      ref = make_ref()

      expect(Deployment.Orchestrator, :conduct, 1, fn new_deployment, tenant ->
        # The supervisor receives the new deployment, whose container
        # deployments must already be visible outside the upgrade transaction.
        new_deployment = Ash.load!(new_deployment, :container_deployments, tenant: tenant)
        send(parent, {ref, new_deployment})
        :ok
      end)

      assert {:ok, new_deployment} =
               deployment
               |> Ash.Changeset.for_update(:upgrade_release, %{target: target_release.id},
                 tenant: tenant
               )
               |> Ash.update(tenant: tenant)

      new_deployment = Ash.load!(new_deployment, :release, tenant: tenant)

      assert new_deployment.release_id != target_release.id
      assert new_deployment.release.version == target_release.version
      assert new_deployment.release.application_id == target_release.application_id
      assert new_deployment.id != deployment.id

      assert_receive {^ref, supervised_deployment}, 1000

      assert supervised_deployment.id == new_deployment.id
      assert supervised_deployment.release_id == new_deployment.release_id

      supervised_deployment =
        Ash.load!(supervised_deployment, [container_deployments: [:container]], tenant: tenant)

      supervised_container_ids =
        supervised_deployment
        |> Map.get(:container_deployments, [])
        |> Enum.map(& &1.container_id)
        |> Enum.sort()

      target_container_ids =
        target_release
        |> Map.get(:containers, [])
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert supervised_container_ids != target_container_ids

      supervised_container_names =
        supervised_deployment
        |> Map.get(:container_deployments, [])
        |> Enum.map(& &1.container.name)
        |> Enum.sort()

      target_container_names =
        target_release
        |> Map.get(:containers, [])
        |> Enum.map(& &1.name)
        |> Enum.sort()

      assert supervised_container_names == target_container_names

      # The upgrade ready action is registered for the new deployment and
      # references the deployment it upgrades
      ready_action =
        ReadyAction
        |> Ash.Query.filter(action_type == :upgrade_deployment)
        |> Ash.read_one!(tenant: tenant)

      assert ready_action.deployment_id == new_deployment.id

      target_id =
        ready_action
        |> Ash.load!(:upgrade_deployment, tenant: tenant)
        |> Map.fetch!(:upgrade_deployment)
        |> Map.fetch!(:upgrade_target_id)

      assert target_id == deployment.id
    end

    test "creates the new deployment without starting a supervisor inside the transaction", %{
      tenant: tenant
    } do
      deployment = ready_deployment_fixture(tenant: tenant)

      target_release =
        release_fixture(
          tenant: tenant,
          application_id: deployment.release.application_id,
          version: "0.0.2"
        )

      expect(Deployment.Orchestrator, :conduct, 1, fn _new_deployment, _tenant -> :ok end)

      assert {:ok, new_deployment} =
               deployment
               |> Ash.Changeset.for_update(:upgrade_release, %{target: target_release.id},
                 tenant: tenant
               )
               |> Ash.update(tenant: tenant)

      new_deployment = Ash.load!(new_deployment, :release, tenant: tenant)
      assert new_deployment.release_id != target_release.id
      assert new_deployment.release.version == target_release.version
    end

    test "applies configs to the new deployment", %{tenant: tenant} do
      deployment = ready_deployment_fixture(tenant: tenant)

      container =
        [
          tenant: tenant,
          file_mounts: [%{mountpoint: "/etc/app.conf", required: true}]
        ]
        |> container_fixture()
        |> Ash.load!(:file_mounts)

      %{file_mounts: [file_mount]} = container

      target_release =
        release_fixture(
          tenant: tenant,
          application_id: deployment.release.application_id,
          version: "0.0.2",
          container_ids: [container.id]
        )

      expect(Deployment.Orchestrator, :conduct, 1, fn _, _ -> :ok end)

      assert {:ok, new_deployment} =
               deployment
               |> Ash.Changeset.for_update(
                 :upgrade_release,
                 %{
                   target: target_release.id,
                   configs: [
                     %{
                       container_id: container.id,
                       env_strategy: :merge,
                       env: [%{key: "FOO", value: "bar"}],
                       file_binds: [%{file_mount_id: file_mount.id}]
                     }
                   ]
                 },
                 tenant: tenant
               )
               |> Ash.update(tenant: tenant)

      new_deployment =
        Ash.load!(
          new_deployment,
          [:release, container_deployments: [file_binds: [:file_mount]]],
          tenant: tenant
        )

      assert new_deployment.release_id != target_release.id
      assert new_deployment.release.version == target_release.version

      assert length(new_deployment.container_deployments) == 1

      [container_deployment] = new_deployment.container_deployments
      assert container_deployment.env == [%{key: "FOO", value: "bar"}]

      assert length(container_deployment.file_binds) == 1

      [file_bind] = container_deployment.file_binds
      assert file_bind.file_mount_id != file_mount.id
      assert file_bind.file_mount.mountpoint == file_mount.mountpoint
    end

    test "detects drift via hash and upgrades to edited same-version release", %{
      tenant: tenant
    } do
      application = application_fixture(tenant: tenant)

      container =
        [
          tenant: tenant,
          hostname: "v1-host",
          file_mounts: [%{mountpoint: "/etc/app.conf", required: false}]
        ]
        |> container_fixture()
        |> Ash.load!(:file_mounts)

      %{file_mounts: [file_mount]} = container

      release =
        release_fixture(
          tenant: tenant,
          application_id: application.id,
          version: "1.0.0",
          container_ids: [container.id]
        )

      deployment =
        [tenant: tenant, release_id: release.id]
        |> deployment_fixture()
        |> make_deployment_ready!(tenant)
        |> Ash.load!(
          [
            release: [
              :hash,
              source_release: [:hash],
              containers: [:hash, source_container: [:hash]]
            ]
          ],
          tenant: tenant
        )

      assert deployment.release.source_release_id == release.id
      assert deployment.release.hash == deployment.release.source_release.hash

      assert [%{hash: container_hash, source_container: %{hash: container_hash}}] =
               deployment.release.containers

      assert {:ok, updated_container} =
               container
               |> Ash.Changeset.for_update(:update, %{hostname: "v1-updated-host"},
                 tenant: tenant
               )
               |> Ash.update(tenant: tenant)

      assert updated_container.hostname == "v1-updated-host"

      deployed_release =
        Ash.load!(
          deployment.release,
          [:hash, source_release: [:hash], containers: [:hash, source_container: [:hash]]],
          tenant: tenant,
          reuse_values?: false
        )

      assert deployed_release.hash != deployed_release.source_release.hash
      [deployed_container] = deployed_release.containers
      assert deployed_container.hash != deployed_container.source_container.hash

      expect(Deployment.Orchestrator, :conduct, 1, fn _, _ -> :ok end)

      assert {:ok, upgraded_deployment} =
               deployment
               |> Ash.Changeset.for_update(
                 :upgrade_release,
                 %{
                   target: release.id,
                   configs: [
                     %{
                       container_id: container.id,
                       env_strategy: :merge,
                       env: [%{key: "UPDATED", value: "true"}],
                       file_binds: [%{file_mount_id: file_mount.id}]
                     }
                   ]
                 },
                 tenant: tenant
               )
               |> Ash.update(tenant: tenant)

      upgraded_deployment =
        Ash.load!(
          upgraded_deployment,
          [
            release: [:hash, source_release: [:hash]],
            container_deployments: [:container, file_binds: [:file_mount]]
          ],
          tenant: tenant
        )

      assert upgraded_deployment.id != deployment.id
      assert upgraded_deployment.release_id != deployment.release_id
      assert upgraded_deployment.release.source_release_id == release.id
      assert upgraded_deployment.release.hash == upgraded_deployment.release.source_release.hash

      [container_deployment] = upgraded_deployment.container_deployments
      assert container_deployment.container.hostname == "v1-updated-host"
      assert container_deployment.env == [%{key: "UPDATED", value: "true"}]

      assert {:ok, fetched} =
               Edgehog.Containers.deployment_by_identity(
                 deployment.device_id,
                 application.id,
                 "1.0.0",
                 tenant: tenant
               )

      assert fetched.id == upgraded_deployment.id
    end

    test "creates a new deployment on same-version upgrade without configs", %{
      tenant: tenant
    } do
      application = application_fixture(tenant: tenant)

      container =
        container_fixture(
          tenant: tenant,
          hostname: "v1-host"
        )

      release =
        release_fixture(
          tenant: tenant,
          application_id: application.id,
          version: "1.0.0",
          container_ids: [container.id]
        )

      deployment =
        [tenant: tenant, release_id: release.id]
        |> deployment_fixture()
        |> make_deployment_ready!(tenant)

      assert {:ok, _updated_container} =
               container
               |> Ash.Changeset.for_update(:update, %{hostname: "v1-updated-host"},
                 tenant: tenant
               )
               |> Ash.update(tenant: tenant)

      expect(Deployment.Orchestrator, :conduct, 1, fn _, _ -> :ok end)

      assert {:ok, upgraded_deployment} =
               deployment
               |> Ash.Changeset.for_update(:upgrade_release, %{target: release.id, configs: []},
                 tenant: tenant
               )
               |> Ash.update(tenant: tenant)

      upgraded_deployment =
        Ash.load!(
          upgraded_deployment,
          [
            release: [:hash, source_release: [:hash]],
            container_deployments: [:container]
          ],
          tenant: tenant
        )

      assert upgraded_deployment.id != deployment.id
      assert upgraded_deployment.release_id != deployment.release_id
      assert upgraded_deployment.release.source_release_id == release.id
      assert upgraded_deployment.release.hash == upgraded_deployment.release.source_release.hash

      [container_deployment] = upgraded_deployment.container_deployments
      assert container_deployment.container.hostname == "v1-updated-host"
    end

    test "computes hash across underlying resources", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      image = image_fixture(tenant: tenant, reference: "nginx:1.25")
      volume = volume_fixture(tenant: tenant, label: "data-vol", driver: "local")
      network = network_fixture(tenant: tenant, label: "app-net", driver: "bridge")

      container =
        container_fixture(
          tenant: tenant,
          image: image,
          networks: [network.id],
          volumes: [%{id: volume.id, target: "/data"}]
        )

      release =
        release_fixture(
          tenant: tenant,
          application_id: application.id,
          version: "1.0.0",
          container_ids: [container.id]
        )

      deployment =
        [tenant: tenant, release_id: release.id]
        |> deployment_fixture()
        |> make_deployment_ready!(tenant)
        |> Ash.load!(
          [
            release: [
              :hash,
              source_release: [:hash],
              containers: [
                :hash,
                source_container: [:hash],
                image: [:hash, source_image: [:hash]],
                networks: [:hash, source_network: [:hash]],
                container_volumes: [:hash, volume: [:hash, source_volume: [:hash]]]
              ]
            ]
          ],
          tenant: tenant
        )

      deployed_release = deployment.release
      assert is_binary(deployed_release.hash)
      assert deployed_release.hash == deployed_release.source_release.hash

      [deployed_container] = deployed_release.containers
      assert is_binary(deployed_container.hash)
      assert deployed_container.hash == deployed_container.source_container.hash

      assert deployed_container.image.hash == deployed_container.image.source_image.hash

      assert [%{hash: net_hash, source_network: %{hash: net_hash}}] =
               deployed_container.networks

      assert [
               %{
                 hash: cv_hash,
                 volume: %{hash: vol_hash, source_volume: %{hash: vol_hash}}
               }
             ] = deployed_container.container_volumes

      assert is_binary(cv_hash)
      assert is_binary(vol_hash)

      assert {:ok, _updated_volume} =
               volume
               |> Ash.Changeset.for_update(:update, %{driver: "custom"}, tenant: tenant)
               |> Ash.update(tenant: tenant)

      deployed_release =
        Ash.load!(
          deployment.release,
          [
            :hash,
            source_release: [:hash],
            containers: [
              :hash,
              source_container: [:hash],
              image: [:hash, source_image: [:hash]],
              networks: [:hash, source_network: [:hash]],
              container_volumes: [:hash, volume: [:hash, source_volume: [:hash]]]
            ]
          ],
          tenant: tenant,
          reuse_values?: false
        )

      assert deployed_release.hash != deployed_release.source_release.hash

      [deployed_container] = deployed_release.containers
      assert deployed_container.hash != deployed_container.source_container.hash
      assert deployed_container.image.hash == deployed_container.image.source_image.hash

      assert [%{hash: net_hash, source_network: %{hash: net_hash}}] =
               deployed_container.networks

      assert [%{volume: updated_deployed_volume}] = deployed_container.container_volumes
      assert updated_deployed_volume.hash != updated_deployed_volume.source_volume.hash
    end
  end

  defp ready_deployment_fixture(tenant: tenant) do
    application = application_fixture(tenant: tenant)

    release =
      release_fixture(
        tenant: tenant,
        application_id: application.id,
        version: "0.0.1",
        containers: 1
      )

    [tenant: tenant, release_id: release.id]
    |> deployment_fixture()
    |> make_deployment_ready!(tenant)
    |> Ash.load!(:release, tenant: tenant)
  end
end
