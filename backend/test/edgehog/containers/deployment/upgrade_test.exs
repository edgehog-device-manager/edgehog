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

defmodule Edgehog.Containers.Deployment.UpgradeTest do
  @moduledoc """
  Tests for upgrading a deployment to a newer release.

  These tests exercise the upgrade path (`upgrade_release` action) and
  specifically the `DeploymentReadyAction.create_deployment` action used to
  create the new deployment. The new deployment must be created without
  starting a deployment supervisor inside the upgrade transaction: the
  supervisor is started by an `after_transaction` hook, so it can only read
  the (now committed) underlying container deployments.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.DeploymentReadyAction

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
          version: "0.0.2"
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

      assert new_deployment.release_id == target_release.id
      assert new_deployment.id != deployment.id

      assert_receive {^ref, supervised_deployment}, 1000

      assert supervised_deployment.id == new_deployment.id
      assert supervised_deployment.release_id == target_release.id

      supervised_containers =
        supervised_deployment
        |> Map.get(:container_deployments, [])
        |> Enum.map(& &1.container_id)
        |> Enum.sort()

      target_containers =
        target_release
        |> Map.get(:containers, [])
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert supervised_containers == target_containers

      # The upgrade ready action is registered for the new deployment and
      # references the deployment it upgrades
      ready_action =
        DeploymentReadyAction
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

      assert new_deployment.release_id == target_release.id
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
