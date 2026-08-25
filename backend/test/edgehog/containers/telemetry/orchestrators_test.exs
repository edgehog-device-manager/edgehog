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
# Unless required by applicable law or agreed to in writing software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Containers.Telemetry.OrchestratorsTest do
  @moduledoc """
  Tests for the deployment and container deployment orchestrator telemetry events.
  """

  use Edgehog.DataCase, async: false

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures
  import Edgehog.TelemetryCapture

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Containers.Container.Deployment.Orchestrator, as: ContainerOrchestrator
  alias Edgehog.Containers.Container.Deployment.Provisioner, as: ContainerProvisioner
  alias Edgehog.Containers.Deployment.Orchestrator, as: DeploymentOrchestrator
  alias Edgehog.Containers.Deployment.Provisioner, as: DeploymentProvisioner
  alias Edgehog.Containers.Image.Deployment.Provisioner, as: ImageProvisioner
  alias Edgehog.Containers.Telemetry

  @moduletag :telemetry

  describe "Deployment orchestrator telemetry" do
    test "emits a successful deployment event when everything is ready" do
      Edgehog.TelemetryCapture.start_capture([
        Telemetry.deployment_start_event(),
        Telemetry.deployment_stop_event()
      ])

      %{tenant: tenant, deployment: deployment} = deployment_ready_fixture()

      {:ok, orchestrator} = DeploymentOrchestrator.conduct(deployment, tenant)

      Sandbox.allow(Edgehog.Repo, self(), orchestrator)

      global_supervisor = Process.whereis(Edgehog.Containers.Deployment.Orchestrator.Supervisor)
      Sandbox.allow(Edgehog.Repo, self(), global_supervisor)

      ref = Process.monitor(orchestrator)

      {measurements, metadata} = assert_receive_event(Telemetry.deployment_start_event())

      assert measurements.count == 1
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id

      # The provisioners are already satisfied (the deployment is ready), so the
      # orchestrator terminates normally as soon as they all report readiness
      assert_receive {:DOWN, ^ref, :process, ^orchestrator, :normal}, 5000

      {measurements, metadata} = assert_receive_event(Telemetry.deployment_stop_event())

      assert measurements.duration >= 0
      assert metadata.duration_unit == :native
      assert metadata.result == :ok
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id
    end

    test "emits a failed deployment event when a container reports a failure" do
      Edgehog.TelemetryCapture.start_capture([
        Telemetry.deployment_start_event(),
        Telemetry.deployment_stop_event()
      ])

      %{tenant: tenant, deployment: deployment} = deployment_ready_fixture()

      topic = DeploymentOrchestrator.topic(deployment)

      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      {:ok, deployment_orchestrator} =
        DeploymentOrchestrator.conduct(deployment, tenant, mode: :manual)

      {measurements, metadata} = assert_receive_event(Telemetry.deployment_start_event())

      assert measurements.count == 1
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id

      test_process = self()

      [container_deployment] =
        deployment
        |> Ash.load!(:container_deployments, tenant: tenant)
        |> Map.get(:container_deployments)

      container_topic = ContainerOrchestrator.topic(container_deployment)

      # The container orchestrator reports a failure while the deployment is
      # being provisioned, so the deployment is failed. The container
      # orchestrator is started through its global dynamic supervisor, so we
      # need to allow that process to use the stub as well
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

      DeploymentOrchestrator.start(deployment_orchestrator)

      assert_receive {:DOWN, ^ref, :process, ^deployment_orchestrator,
                      {:shutdown, :deployment_failed}},
                     2000

      {measurements, metadata} = assert_receive_event(Telemetry.deployment_stop_event())

      assert measurements.duration >= 0
      assert metadata.duration_unit == :native
      assert metadata.result == :error
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end
  end

  describe "Container deployment orchestrator telemetry" do
    test "emits a successful container deployment event when everything is ready" do
      Edgehog.TelemetryCapture.start_capture([
        Telemetry.container_deployment_start_event(),
        Telemetry.container_deployment_stop_event()
      ])

      %{
        tenant: tenant,
        deployment: deployment,
        container_deployment: container_deployment
      } = container_deployment_ready_fixture()

      topic = ContainerOrchestrator.topic(container_deployment)

      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      # Start the container orchestrator in manual mode, so that we can allow
      # the whole tree to the sandbox before any provisioning step reads from
      # the database
      {:ok, orchestrator} =
        ContainerOrchestrator.conduct(container_deployment, deployment, tenant, mode: :manual)

      {measurements, metadata} =
        assert_receive_event(Telemetry.container_deployment_start_event())

      assert measurements.count == 1
      assert metadata.container_deployment_id == container_deployment.id
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id

      Sandbox.allow(Edgehog.Repo, self(), orchestrator)

      ContainerOrchestrator.start(orchestrator)

      # Wait for processes to start and register on each registry
      Process.sleep(500)

      # Drive each provisioner: they all find their resource already ready, so
      # they report readiness and let the orchestrator proceed
      image_provisioner =
        container_deployment.image_deployment
        |> ImageProvisioner.Core.name()
        |> via_pid!()

      Sandbox.allow(Edgehog.Repo, self(), image_provisioner)
      ImageProvisioner.run(image_provisioner)

      container_provisioner =
        container_deployment
        |> ContainerProvisioner.Core.name()
        |> via_pid!()

      Sandbox.allow(Edgehog.Repo, self(), container_provisioner)
      ContainerProvisioner.run(container_provisioner)

      # When all the provisioners are satisfied, the container orchestrator
      # broadcasts the readiness of the container deployment
      assert_receive %Phoenix.Socket.Broadcast{event: :ready, payload: new_container_deployment},
                     5000

      assert new_container_deployment.id == container_deployment.id

      {measurements, metadata} = assert_receive_event(Telemetry.container_deployment_stop_event())

      assert measurements.duration >= 0
      assert metadata.duration_unit == :native
      assert metadata.result == :ok
      assert metadata.container_deployment_id == container_deployment.id
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end

    test "emits a failed container deployment event when a leaf provisioner cannot be started" do
      Edgehog.TelemetryCapture.start_capture([
        Telemetry.container_deployment_start_event(),
        Telemetry.container_deployment_stop_event()
      ])

      %{
        tenant: tenant,
        deployment: deployment,
        container_deployment: container_deployment
      } = container_deployment_ready_fixture()

      topic = ContainerOrchestrator.topic(container_deployment)

      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      {:ok, container_orchestrator} =
        ContainerOrchestrator.conduct(container_deployment, deployment, tenant, mode: :manual)

      {measurements, metadata} =
        assert_receive_event(Telemetry.container_deployment_start_event())

      assert measurements.count == 1
      assert metadata.container_deployment_id == container_deployment.id
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id

      Sandbox.allow(Edgehog.Repo, self(), container_orchestrator)

      orchestrator =
        container_deployment
        |> ContainerOrchestrator.name()
        |> via_pid!()

      test_process = self()

      # The image provisioner fails to start, so the container deployment is
      # failed. The leaf provisioner is started through its global dynamic
      # supervisor, so we need to allow that process to use the stub as well
      image_supervisor = Process.whereis(Edgehog.Containers.Image.Provisioner.Supervisor)

      ImageProvisioner
      |> allow(test_process, image_supervisor)
      |> stub(:start_link, fn _args -> {:error, :mocked_failure} end)

      ref = Process.monitor(orchestrator)

      ContainerOrchestrator.start(orchestrator)

      assert_receive {:DOWN, ^ref, :process, ^orchestrator, {:shutdown, :container_failed}}, 2000

      {measurements, metadata} = assert_receive_event(Telemetry.container_deployment_stop_event())

      assert measurements.duration >= 0
      assert metadata.duration_unit == :native
      assert metadata.result == :error
      assert metadata.container_deployment_id == container_deployment.id
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end
  end

  defp deployment_ready_fixture do
    tenant = tenant_fixture()
    deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

    deployment = make_deployment_ready!(deployment, tenant)
    mark_device_online!(deployment, tenant)

    %{tenant: tenant, deployment: deployment}
  end

  defp container_deployment_ready_fixture do
    tenant = tenant_fixture()
    deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

    deployment = make_deployment_ready!(deployment, tenant)

    [container_deployment] =
      deployment
      |> Ash.load!(
        [container_deployments: [:container, :image_deployment]],
        tenant: tenant
      )
      |> Map.get(:container_deployments, [])

    mark_device_online!(deployment, tenant)

    %{
      tenant: tenant,
      deployment: deployment,
      container_deployment: container_deployment
    }
  end

  defp via_pid!({:via, Registry, {registry, key}}) do
    case Registry.lookup(registry, key) do
      [{pid, _value}] ->
        pid

      _other ->
        raise "no process registered for #{inspect(key)} in #{inspect(registry)}"
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
