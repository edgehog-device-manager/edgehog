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
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Deployment.Supervisor

  describe "Container deployment supervisor" do
    setup do
      tenant = tenant_fixture()
      deployment = deployment_fixture(tenant: tenant)

      {:ok, supervisor} =
        Supervisor.supervise(deployment, tenant, mode: :manual)

      Sandbox.allow(Edgehog.Repo, self(), supervisor)

      ref = Process.monitor(supervisor)

      %{
        tenant: tenant,
        deployment: deployment,
        supervisor: supervisor,
        supervisor_ref: ref
      }
    end

    test "Calls the underlying provisioners", context do
      %{
        supervisor: supervisor,
        supervisor_ref: ref
      } = context

      test_process = self()

      Deployment.Provisioner
      |> allow(test_process, supervisor)
      |> expect(:provision, fn deployment, _tenant ->
        assert deployment == deployment

        %{id: id} = deployment

        # Simulate provisioning process finishing with correct readiness
        Phoenix.PubSub.broadcast!(
          Edgehog.PubSub,
          "ready:deployments:#{id}",
          {:ready, deployment}
        )
      end)

      Supervisor.start(supervisor)

      assert_receive {:DOWN, ^ref, :process, ^supervisor, :normal}, 1000
    end
  end
end
