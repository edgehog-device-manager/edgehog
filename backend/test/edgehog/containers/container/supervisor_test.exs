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

defmodule Edgehog.Containers.Container.Deployment.SupervisorTest do
  @moduledoc """
  Tests for the container deployment supervisor.

  These tests ensure the correct behavior of the supervisor, mocking the calls
  to the underlying resource supervisors.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Container.Deployment.Supervisor
  alias Edgehog.Containers.Image

  describe "Container deployment supervisor" do
    setup do
      tenant = tenant_fixture()
      deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

      [container_deployment] =
        deployment
        |> Ash.load!([container_deployments: [:container]], tenant: tenant)
        |> Map.get(:container_deployments, [])

      {:ok, supervisor} =
        Supervisor.supervise(container_deployment, deployment, tenant, mode: :manual)

      Sandbox.allow(Edgehog.Repo, self(), supervisor)

      ref = Process.monitor(supervisor)

      %{
        tenant: tenant,
        deployment: deployment,
        container_deployment: container_deployment,
        supervisor: supervisor,
        supervisor_ref: ref
      }
    end

    test "Calls the underlying provisioners", context do
      %{
        container_deployment: original_container_deployment,
        supervisor: supervisor,
        supervisor_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      original_image_deployment =
        original_container_deployment
        |> Ash.load!([:image_deployment], tenant: tenant)
        |> Map.fetch!(:image_deployment)

      Image.Deployment.Provisioner
      |> allow(test_process, supervisor)
      |> expect(:provision, fn image_deployment, deployment, _tenant ->
        assert deployment == deployment
        assert image_deployment == original_image_deployment

        %{id: id} = image_deployment

        # Simulate provisioning process finishing with correct readiness
        Phoenix.PubSub.broadcast!(
          Edgehog.PubSub,
          "ready:image_deployment:#{id}",
          {:ready, image_deployment}
        )
      end)

      Container.Deployment.Provisioner
      |> allow(test_process, supervisor)
      |> expect(:provision, fn container_deployment, deployment, _tenant ->
        assert deployment == deployment
        assert container_deployment == original_container_deployment

        %{id: id} = container_deployment

        # Simulate provisioning process finishing with correct readiness
        Phoenix.PubSub.broadcast!(
          Edgehog.PubSub,
          "ready:container_deployment:#{id}",
          {:ready, container_deployment}
        )
      end)

      Supervisor.start(supervisor)

      assert_receive {:DOWN, ^ref, :process, ^supervisor, :normal}, 1000
    end
  end
end
