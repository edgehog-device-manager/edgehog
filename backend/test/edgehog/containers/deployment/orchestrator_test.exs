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

defmodule Edgehog.Containers.Deployment.OrchestratorTest do
  @moduledoc """
  Tests for the deployment provisioning tree.

  These tests ensure the correct behavior of the deployment orchestrator,
  starting a provisioning tree whose leaf provisioners find all underlying
  resources already ready (and the device online), so that the whole tree
  finishes and the deployment orchestrator terminates normally.
  """

  use Edgehog.DataCase, async: false

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Containers.Container.Deployment.Orchestrator, as: ContainerOrchestrator
  alias Edgehog.Containers.Deployment.Orchestrator
  alias Edgehog.Containers.Deployment.Provisioner, as: DeploymentProvisioner

  describe "Deployment orchestrator" do
    setup do
      tenant = tenant_fixture()
      deployment = deployment_fixture(tenant: tenant)

      deployment = make_deployment_ready!(deployment, tenant)

      # The device must be online for the provisioning to succeed
      mark_device_online!(deployment, tenant)

      %{
        tenant: tenant,
        deployment: deployment
      }
    end

    test "Calls the underlying provisioners", context do
      %{
        deployment: deployment,
        tenant: tenant
      } = context

      {:ok, orchestrator} = Orchestrator.conduct(deployment, tenant)

      # The provisioners are started by the global orchestrator supervisor, so we
      # need to propagate the sandbox ownership both from the orchestrator and
      # from the global supervisor itself
      Sandbox.allow(Edgehog.Repo, self(), orchestrator)

      global_supervisor = Process.whereis(Edgehog.Containers.Deployment.Orchestrator.Supervisor)

      Sandbox.allow(Edgehog.Repo, self(), global_supervisor)

      ref = Process.monitor(orchestrator)

      # The provisioners are already satisfied, so the orchestrator terminates
      # normally as soon as they all report readiness
      assert_receive {:DOWN, ^ref, :process, ^orchestrator, :normal}, 5000
    end

    test "fails the deployment when a container reports a failure", %{tenant: _setup_tenant} do
      tenant = tenant_fixture()
      deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

      deployment = make_deployment_ready!(deployment, tenant)
      mark_device_online!(deployment, tenant)

      topic = Orchestrator.topic(deployment)

      # Subscribe to the deployment readiness
      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      {:ok, deployment_orchestrator} =
        Orchestrator.conduct(deployment, tenant, mode: :manual)

      test_process = self()

      [container_deployment] =
        deployment
        |> Ash.load!(:container_deployments, tenant: tenant)
        |> Map.get(:container_deployments)

      container_topic = ContainerOrchestrator.topic(container_deployment)

      # The container orchestrator reports a failure while the deployment is
      # being provisioned, so the deployment is failed instead of waiting for
      # anything else. The container orchestrator is started through its global
      # dynamic supervisor, so we need to allow that process to use the stub as
      # well
      ContainerOrchestrator
      |> allow(test_process, deployment_orchestrator)
      |> expect(:conduct, fn _container_deployment, _deployment, _tenant ->
        Phoenix.PubSub.broadcast!(
          Edgehog.PubSub,
          container_topic,
          %Phoenix.Socket.Broadcast{
            topic: container_topic,
            event: :failure,
            payload: container_deployment
          }
        )

        {:ok, self()}
      end)

      # The deployment provisioner is not needed for this test, stub it so that
      # no real provisioner is started
      DeploymentProvisioner
      |> allow(test_process, deployment_orchestrator)
      |> stub(:provision, fn _deployment, _tenant -> {:ok, self()} end)

      ref = Process.monitor(deployment_orchestrator)

      Orchestrator.start(deployment_orchestrator)

      assert_receive {:DOWN, ^ref, :process, ^deployment_orchestrator,
                      {:shutdown, :deployment_failed}},
                     2000

      # The failure is broadcast on the deployment readiness topic
      assert_receive %Phoenix.Socket.Broadcast{
                       event: :failure,
                       payload: failed_deployment
                     },
                     2000

      assert failed_deployment.id == deployment.id

      # The deployment is marked as timed out
      deployment = Ash.get!(Edgehog.Containers.Deployment, deployment.id, tenant: tenant)
      assert deployment.timed_out

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end
  end

  defp mark_device_online!(deployment, tenant) do
    timestamp = DateTime.now!("Etc/UTC")

    opts = %{
      online: true,
      last_connection: timestamp,
      last_disconnection: timestamp
    }

    deployment
    |> Map.get(:device)
    |> Ash.Changeset.for_update(:from_device_status, opts)
    |> Ash.update!(tenant: tenant)
  end
end
