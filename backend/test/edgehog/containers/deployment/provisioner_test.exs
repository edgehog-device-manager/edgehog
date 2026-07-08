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
  alias Edgehog.Astarte.Device.CreateDeploymentRequest
  alias Edgehog.Containers.Deployment.Provisioner

  describe "Deployment provisioner" do
    setup do
      tenant = tenant_fixture()
      deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

      provisioner =
        Provisioner.start_link(
          tenant: tenant,
          deployment: deployment,
          mode: :manual
        )

      provisioner =
        case provisioner do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      ref = Process.monitor(provisioner)

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

      Provisioner.start(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end

    test "sets-up an image on a device after a retry", context do
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

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.start(provisioner)

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

      Phoenix.PubSub.subscribe(Edgehog.PubSub, "ready:deployments:#{deployment.id}")

      Provisioner.start(provisioner)

      assert_receive {:ready, new_deployment}, 1000

      assert new_deployment.id == deployment.id
      assert new_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "ready:deployments:#{deployment.id}")
    end
  end
end
