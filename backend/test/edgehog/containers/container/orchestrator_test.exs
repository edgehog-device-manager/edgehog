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

defmodule Edgehog.Containers.Container.Deployment.OrchestratorTest do
  @moduledoc """
  Tests for the container deployment provisioning tree.

  These tests ensure the correct behavior of the container deployment
  orchestrator, starting a provisioning tree whose leaf provisioners find all
  underlying resources already ready (and the device online), so that the
  container orchestrator broadcasts the readiness of the container deployment.
  """

  use Edgehog.DataCase, async: false

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Astarte.Device.CreateBind
  alias Edgehog.Containers.Container.Deployment.Orchestrator
  alias Edgehog.Containers.Container.Deployment.Provisioner
  alias Edgehog.Containers.FileBind.Provisioner, as: FileBindProvisioner
  alias Edgehog.Containers.Image.Deployment.Provisioner, as: ImageProvisioner

  describe "Container deployment orchestrator" do
    setup do
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

      # The device must be online for the provisioning to succeed
      mark_device_online!(deployment, tenant)

      %{
        tenant: tenant,
        deployment: deployment,
        container_deployment: container_deployment
      }
    end

    test "Calls the underlying provisioners", context do
      %{
        deployment: deployment,
        container_deployment: container_deployment,
        tenant: tenant
      } = context

      topic = Orchestrator.topic(container_deployment)

      # Subscribe to the container deployment readiness
      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      # Start the container orchestrator in manual mode, so that we can allow
      # the whole tree to the sandbox before any provisioning step reads from
      # the database
      {:ok, orchestrator} =
        Orchestrator.conduct(container_deployment, deployment, tenant, mode: :manual)

      # Supervised processes do not inherit the sandbox ownership, so we need to
      # allow the container orchestrator and each leaf provisioner explicitly
      Sandbox.allow(Edgehog.Repo, self(), orchestrator)

      # Kick off the provisioning. The orchestrator loads the resources and
      # starts the leaf provisioners, which are left in manual mode
      Orchestrator.start(orchestrator)

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
        |> Provisioner.Core.name()
        |> via_pid!()

      Sandbox.allow(Edgehog.Repo, self(), container_provisioner)
      Provisioner.run(container_provisioner)

      # When all the provisioners are satisfied, the container orchestrator
      # broadcasts the readiness of the container deployment
      assert_receive %Phoenix.Socket.Broadcast{event: :ready, payload: new_container_deployment},
                     5000

      assert new_container_deployment.id == container_deployment.id

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end

    test "provisions file binds like any other resource", context do
      %{tenant: tenant} = context

      device = device_fixture(tenant: tenant)

      container =
        [tenant: tenant, file_mounts: [%{mountpoint: "/etc/app.conf", required: false}]]
        |> container_fixture()
        |> Ash.load!(:file_mounts)

      %{file_mounts: [file_mount]} = container

      release = release_fixture(tenant: tenant, container_ids: [container.id])

      deployment =
        deployment_fixture(tenant: tenant, device_id: device.id, release_id: release.id)

      file_request = manual_file_download_request_fixture(tenant: tenant, device_id: device.id)

      [container_deployment] =
        deployment
        |> Ash.load!([container_deployments: [:container]], tenant: tenant)
        |> Map.get(:container_deployments, [])

      file_bind =
        file_bind_fixture(
          tenant: tenant,
          container_deployment_id: container_deployment.id,
          file_mount_id: file_mount.id,
          file_download_request_id: file_request.id
        )

      deployment = make_deployment_ready!(deployment, tenant)
      mark_device_online!(deployment, tenant)

      # Reload the container deployment, as readiness was changed above
      container_deployment =
        Ash.get!(Edgehog.Containers.Container.Deployment, container_deployment.id, tenant: tenant)

      topic = Orchestrator.topic(container_deployment)

      # Subscribe to the container deployment readiness
      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      # Start the container orchestrator in manual mode, so that we can allow
      # the whole tree to the sandbox before any provisioning step reads from
      # the database
      {:ok, orchestrator} =
        Orchestrator.conduct(container_deployment, deployment, tenant, mode: :manual)

      Sandbox.allow(Edgehog.Repo, self(), orchestrator)

      # Kick off the provisioning. The orchestrator loads the resources and
      # starts the leaf provisioners, which are left in manual mode
      Orchestrator.start(orchestrator)

      # Wait for processes to start and register on each registry
      Process.sleep(500)

      # Drive the file bind provisioner: it sends the CreateFileBindRequest
      # to the device, and completes once the device reports the bind
      file_bind_provisioner =
        file_bind
        |> FileBindProvisioner.Core.name()
        |> via_pid!()

      Sandbox.allow(Edgehog.Repo, self(), file_bind_provisioner)

      test_process = self()

      CreateBind
      |> allow(test_process, file_bind_provisioner)
      |> expect(:send_bind, fn _client, _device_id, data ->
        assert data.id == file_bind.id
        assert data.deploymentId == deployment.id
        assert data.targetId == file_request.id
        assert data.targetType == "request"
        assert data.mountpoint == "/etc/app.conf"

        # Simulate the device reporting the bind through AvailableFileBinds
        file_bind
        |> Ash.Changeset.for_update(:mark_as_available)
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      ref = Process.monitor(file_bind_provisioner)

      FileBindProvisioner.run(file_bind_provisioner)

      assert_receive {:DOWN, ^ref, :process, ^file_bind_provisioner, :normal}, 5000

      # Drive the remaining provisioners: they all find their resource
      # already ready, so they report readiness and let the orchestrator
      # proceed
      image_provisioner =
        container_deployment
        |> Ash.load!(:image_deployment, tenant: tenant)
        |> Map.get(:image_deployment)
        |> ImageProvisioner.Core.name()
        |> via_pid!()

      Sandbox.allow(Edgehog.Repo, self(), image_provisioner)
      ImageProvisioner.run(image_provisioner)

      container_provisioner =
        container_deployment
        |> Provisioner.Core.name()
        |> via_pid!()

      Sandbox.allow(Edgehog.Repo, self(), container_provisioner)
      Provisioner.run(container_provisioner)

      # When all the provisioners are satisfied, the container orchestrator
      # broadcasts the readiness of the container deployment
      assert_receive %Phoenix.Socket.Broadcast{event: :ready, payload: new_container_deployment},
                     5000

      assert new_container_deployment.id == container_deployment.id

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end

    test "fails the container deployment if a leaf provisioner cannot be started", context do
      %{
        deployment: deployment,
        container_deployment: container_deployment,
        tenant: tenant
      } = context

      topic = Orchestrator.topic(container_deployment)

      # Subscribe to the container deployment readiness
      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      {:ok, container_orchestrator} =
        Orchestrator.conduct(container_deployment, deployment, tenant, mode: :manual)

      Sandbox.allow(Edgehog.Repo, self(), container_orchestrator)

      orchestrator =
        container_deployment
        |> Orchestrator.name()
        |> via_pid!()

      test_process = self()

      # The image provisioner fails to start, so the container deployment cannot
      # be provisioned and is failed instead of waiting for the deadline. The
      # leaf provisioner is started through its global dynamic supervisor, so we
      # need to allow that process to use the stub as well
      image_supervisor = Process.whereis(Edgehog.Containers.Image.Provisioner.Supervisor)

      ImageProvisioner
      |> allow(test_process, image_supervisor)
      |> stub(:start_link, fn _args -> {:error, :mocked_failure} end)

      ref = Process.monitor(orchestrator)

      Orchestrator.start(orchestrator)

      assert_receive {:DOWN, ^ref, :process, ^orchestrator, {:shutdown, :container_failed}}, 2000

      # The failure is broadcast on the container deployment readiness topic
      assert_receive %Phoenix.Socket.Broadcast{
                       event: :failure,
                       payload: failed_container_deployment
                     },
                     2000

      assert failed_container_deployment.id == container_deployment.id

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end

    test "fails the container deployment when a leaf provisioner broadcasts a failure", context do
      %{
        deployment: deployment,
        container_deployment: container_deployment,
        tenant: tenant
      } = context

      topic = Orchestrator.topic(container_deployment)

      # Subscribe to the container deployment readiness
      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      {:ok, orchestrator} =
        Orchestrator.conduct(container_deployment, deployment, tenant, mode: :manual)

      Sandbox.allow(Edgehog.Repo, self(), orchestrator)
      test_process = self()

      # The image provisioner reports a failure while the container deployment is
      # being provisioned, so the container deployment is failed instead of
      # waiting for anything else
      ImageProvisioner
      |> allow(test_process, orchestrator)
      |> expect(:provision, fn image_deployment, _tenant, _opts ->
        %{id: id} = image_deployment

        Phoenix.PubSub.broadcast!(
          Edgehog.PubSub,
          "ready:image_deployments:#{id}",
          {:failure, image_deployment}
        )

        {:ok, self()}
      end)

      ref = Process.monitor(orchestrator)

      Orchestrator.start(orchestrator)

      assert_receive {:DOWN, ^ref, :process, ^orchestrator, {:shutdown, :container_failed}}, 2000

      # The failure is broadcast on the container deployment readiness topic
      assert_receive %Phoenix.Socket.Broadcast{
                       event: :failure,
                       payload: failed_container_deployment
                     },
                     2000

      assert failed_container_deployment.id == container_deployment.id

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end
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
