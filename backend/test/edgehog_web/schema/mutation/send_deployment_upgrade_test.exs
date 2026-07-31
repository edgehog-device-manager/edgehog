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

defmodule EdgehogWeb.Schema.Mutation.SendDeploymentUpgradeTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Astarte.Device.DeploymentUpdate
  alias Edgehog.Containers
  alias Edgehog.Containers.Deployment

  describe "sendDeploymentUpgrade" do
    setup %{tenant: tenant} do
      release_0_0_1 =
        release_fixture(version: "0.0.1", tenant: tenant)

      release_0_0_2 =
        release_fixture(
          application_id: release_0_0_1.application_id,
          version: "0.0.2",
          tenant: tenant
        )

      %{
        release_0_0_1: release_0_0_1,
        release_0_0_2: release_0_0_2
      }
    end

    test "correctly sends the deployment request with valid data", args do
      %{release_0_0_1: release_0_0_1, release_0_0_2: release_0_0_2, tenant: tenant} =
        args

      # we need to set the state of deployment in one of ready states so the action validation passes
      {:ok, deployment_0_0_1} =
        [release_id: release_0_0_1.id, tenant: tenant]
        |> deployment_fixture()
        |> Containers.mark_deployment_as_stopped(tenant: tenant)

      expect(Deployment.Supervisor, :supervise, fn _, _ -> :ok end)

      result =
        [tenant: tenant, deployment: deployment_0_0_1, target: release_0_0_2]
        |> send_deployment_upgrade_mutation()
        |> extract_result!()

      {:ok, %{id: deployment_id}} = AshGraphql.Resource.decode_relay_id(result["id"])

      assert Edgehog.Containers.DeploymentReadyAction
             |> Ash.read_first!(tenant: tenant)
             |> Map.fetch!(:deployment_id) == deployment_id
    end

    test "supervises the new deployment with its container deployments loaded", args do
      %{tenant: tenant} = args

      application = application_fixture(tenant: tenant)

      release_0_0_1 =
        release_fixture(
          tenant: tenant,
          application_id: application.id,
          version: "0.0.1",
          containers: 1
        )

      release_0_0_2 =
        release_fixture(
          tenant: tenant,
          application_id: application.id,
          version: "0.0.2",
          containers: 1
        )

      deployment_0_0_1 =
        [release_id: release_0_0_1.id, tenant: tenant]
        |> deployment_fixture()
        |> make_deployment_ready!(tenant)

      parent = self()
      ref = make_ref()

      expect(Deployment.Supervisor, :supervise, fn new_deployment, tenant ->
        new_deployment = Ash.load!(new_deployment, :container_deployments, tenant: tenant)
        send(parent, {ref, new_deployment})
        :ok
      end)

      result =
        [tenant: tenant, deployment: deployment_0_0_1, target: release_0_0_2]
        |> send_deployment_upgrade_mutation()
        |> extract_result!()

      {:ok, %{id: deployment_id}} = AshGraphql.Resource.decode_relay_id(result["id"])

      assert_receive {^ref, supervised_deployment}, 1000

      assert supervised_deployment.id == deployment_id
      assert supervised_deployment.release_id == release_0_0_2.id

      # The supervisor must see the container deployments of the new release
      container_ids =
        release_0_0_2
        |> Ash.load!(:containers, tenant: tenant)
        |> Map.fetch!(:containers)
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert supervised_deployment.container_deployments
             |> Enum.map(& &1.container_id)
             |> Enum.sort() == container_ids
    end

    test "sends the deployment upgrade once the new deployment is ready", args do
      %{release_0_0_1: release_0_0_1, release_0_0_2: release_0_0_2, tenant: tenant} =
        args

      # We need to set the state of deployment in one of ready states so the
      # action validation passes
      {:ok, deployment_0_0_1} =
        [release_id: release_0_0_1.id, tenant: tenant]
        |> deployment_fixture()
        |> Containers.mark_deployment_as_stopped(tenant: tenant)

      test_process = self()

      expect(Deployment.Supervisor, :supervise, fn deployment, tenant ->
        args = [
          tenant: tenant,
          deployment: deployment,
          mode: :manual
        ]

        {:ok, supervisor} = Mimic.call_original(Deployment.Supervisor, :start_link, [args])

        Sandbox.allow(Edgehog.Repo, test_process, supervisor)

        # Send the supervisor pid to the test process
        send(test_process, {:supervisor, supervisor})
      end)

      result =
        [tenant: tenant, deployment: deployment_0_0_1, target: release_0_0_2]
        |> send_deployment_upgrade_mutation()
        |> extract_result!()

      {:ok, %{id: deployment_id}} = AshGraphql.Resource.decode_relay_id(result["id"])

      # Receive the supervisor pid
      assert_receive {:supervisor, sup}, 1000

      ref = Process.monitor(sup)

      # The update deploys the new version
      Deployment.Provisioner
      |> allow(test_process, sup)
      |> expect(:provision, fn deployment, _ ->
        topic = Deployment.Provisioner.topic(deployment)

        # Broadcast readiness
        Phoenix.PubSub.broadcast(Edgehog.PubSub, topic, {:ready, deployment})
      end)

      # And sends the update command
      DeploymentUpdate
      |> allow(test_process, sup)
      |> expect(:update, fn _, _, data ->
        assert data.to == deployment_id

        :ok
      end)

      Deployment.Supervisor.start(sup)

      # Assert supervisor shuts down correctly
      assert_receive {:DOWN, ^ref, :process, ^sup, :normal}, 2000
    end

    test "fails if the deployments do not belong to the same application", args do
      %{release_0_0_1: release_0_0_1, release_0_0_2: release_0_0_2, tenant: tenant} =
        args

      # we need to set the state of deployment in one of ready states so the action validation passes
      {:ok, deployment_0_0_1} =
        [release_id: release_0_0_1.id, tenant: tenant]
        |> deployment_fixture()
        |> Containers.mark_deployment_as_stopped(tenant: tenant)

      release_0_0_2_b = release_fixture(version: release_0_0_2.version, tenant: tenant)

      [tenant: tenant, deployment: deployment_0_0_1, target: release_0_0_2_b]
      |> send_deployment_upgrade_mutation()
      |> extract_error!()
    end

    test "fails if the second deployment does not have a greater version than the first", args do
      %{release_0_0_1: release_0_0_1, release_0_0_2: release_0_0_2, tenant: tenant} =
        args

      # we need to set the state of deployment in one of ready states so the action validation passes
      {:ok, deployment_0_0_2} =
        [release_id: release_0_0_2.id, tenant: tenant]
        |> deployment_fixture()
        |> Containers.mark_deployment_as_stopped(tenant: tenant)

      [tenant: tenant, deployment: deployment_0_0_2, target: release_0_0_1]
      |> send_deployment_upgrade_mutation()
      |> extract_error!()
    end

    test "fails when deployment is in non ready state", args do
      %{release_0_0_1: release_0_0_1, release_0_0_2: release_0_0_2, tenant: tenant} =
        args

      deployment_0_0_1 =
        deployment_fixture(release_id: release_0_0_1.id, tenant: tenant)

      reject(&Deployment.Supervisor.supervise/2)

      _result =
        [tenant: tenant, deployment: deployment_0_0_1, target: release_0_0_2]
        |> send_deployment_upgrade_mutation()
        |> extract_error!()
    end
  end

  defp send_deployment_upgrade_mutation(opts) do
    default_document = """
    mutation UpgradeDeployment($id: ID!, $input: UpgradeDeploymentInput!) {
      upgradeDeployment(id: $id, input: $input) {
        result {
          id
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)
    target = Keyword.fetch!(opts, :target)

    input = %{
      "target" => AshGraphql.Resource.encode_relay_id(target)
    }

    variables = %{
      "id" => AshGraphql.Resource.encode_relay_id(deployment),
      "input" => input
    }

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  def extract_result!(result) do
    refute :errors in Map.keys(result)

    assert %{
             data: %{
               "upgradeDeployment" => %{
                 "result" => result
               }
             }
           } = result

    assert result

    result
  end

  defp extract_error!(result) do
    assert %{
             data: %{"upgradeDeployment" => nil},
             errors: [error]
           } = result

    error
  end
end
