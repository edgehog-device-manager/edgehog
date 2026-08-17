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

defmodule Edgehog.Containers.Deployment.ProvisionerTest do
  @moduledoc """
  Tests for the deployment provisioner.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Astarte.Device.AvailableDeployments
  alias Edgehog.Astarte.Device.AvailableDeployments.DeploymentStatus
  alias Edgehog.Astarte.Device.CreateDeploymentRequest
  alias Edgehog.Config
  alias Edgehog.Containers.Deployment.Provisioner

  describe "Deployment provisioner" do
    setup do
      tenant = tenant_fixture()

      deployment =
        [tenant: tenant, release_opts: [containers: 1]]
        |> deployment_fixture()
        |> Ash.load!(:device, tenant: tenant)

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

      provisioner =
        Provisioner.start(
          tenant: tenant,
          resource: deployment,
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
        provisioner: provisioner,
        provisioner_ref: ref
      }
    end

    test "sets-up a deployment on a device", context do
      %{
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateDeploymentRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_deployment_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateDeploymentRequest.RequestData{
          id: id,
          containers: containers
        } = data

        [container_id] = containers

        [container_deployment] =
          deployment
          |> Ash.load!([container_deployments: [:container, :image_deployment]], tenant: tenant)
          |> Map.get(:container_deployments, [])

        container = container_deployment.container
        image_deployment = container_deployment.image_deployment

        assert id == deployment.id
        assert container_id == container.id

        # Update the deployment to be ready

        image_deployment
        |> Ash.Changeset.for_update(:mark_as_unpulled, %{})
        |> Ash.update!(tenant: tenant)

        container_deployment
        |> Ash.Changeset.for_update(:mark_as_created, %{})
        |> Ash.update!(tenant: tenant)

        deployment
        |> Ash.Changeset.for_update(:mark_as_stopped, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end

    test "sets-up a deployment on a device after a retry", context do
      %{
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateDeploymentRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_deployment_request, fn _, _, _ ->
        {:error, %Astarte.Client.APIError{status: 500, response: "some error message"}}
      end)
      |> expect(:send_create_deployment_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateDeploymentRequest.RequestData{
          id: id,
          containers: containers
        } = data

        [container_id] = containers

        [container] =
          deployment
          |> Ash.load!([container_deployments: [:container]], tenant: tenant)
          |> Map.get(:container_deployments, [])
          |> Enum.map(& &1.container)

        assert id == deployment.id
        assert container_id == container.id

        # Update the deployment to be ready

        deployment
        |> Ash.Changeset.for_update(:mark_as_stopped, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Provisioner.run(provisioner)

      # 2000 as the retry might happen between 0 and 1 second
      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 2000
    end

    test "emits :ready on correct topic on provisioning completion", context do
      %{
        deployment: deployment,
        provisioner: provisioner,
        tenant: tenant
      } = context

      test_process = self()

      CreateDeploymentRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_deployment_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateDeploymentRequest.RequestData{
          id: id,
          containers: containers
        } = data

        [container_id] = containers

        [container] =
          deployment
          |> Ash.load!([container_deployments: [:container]], tenant: tenant)
          |> Map.get(:container_deployments, [])
          |> Enum.map(& &1.container)

        assert id == deployment.id
        assert container_id == container.id

        # Update the deployment to be ready

        deployment
        |> Ash.Changeset.for_update(:mark_as_stopped, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      # External services expect to be able to subscribe to this topic
      topic = Provisioner.Core.topic(deployment)

      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      Provisioner.run(provisioner)

      assert_receive {:ready, new_deployment}, 1000

      assert new_deployment.id == deployment.id
      assert new_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end

    test "doesn't send deployment if it's ready", context do
      %{
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateDeploymentRequest
      |> allow(test_process, provisioner)
      |> reject(:send_create_deployment_request, 3)

      Sandbox.allow(Edgehog.Repo, test_process, provisioner)

      ready_topic = Provisioner.Core.topic(deployment.id)
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      deployment =
        deployment
        |> Ash.Changeset.for_update(:mark_as_stopped, %{})
        |> Ash.update!(tenant: tenant)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
      assert_receive {:ready, new_deployment}, 1000

      assert new_deployment.id == deployment.id
      assert new_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, ready_topic)
    end

    test "reconciles the state with astarte if a timeout on send is found", context do
      %{
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      } = context

      test_process = self()

      # Remove the Pan
      Config
      |> allow(test_process, provisioner)
      |> stub(:message_min_timeout!, fn -> 0 end)

      CreateDeploymentRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_deployment_request, fn _, _, _ ->
        :ok
      end)

      device_id = deployment.device.device_id

      AvailableDeployments
      |> allow(test_process, provisioner)
      |> expect(:get, fn _client, ^device_id ->
        containers = [
          %DeploymentStatus{id: deployment.id, status: :stopped}
        ]

        {:ok, containers}
      end)

      ready_topic = Provisioner.Core.topic(deployment)
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 3000
      assert_receive {:ready, new_deployment}, 3000

      assert new_deployment.id == deployment.id
      assert new_deployment.is_ready

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

      CreateDeploymentRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_deployment_request, fn _, _, _ -> :ok end)

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

      CreateDeploymentRequest
      |> allow(test_process, provisioner)
      |> reject(:send_create_deployment_request, 3)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :device_offline}}, 2000
    end
  end

  defp now, do: DateTime.now!("Etc/UTC")
end
