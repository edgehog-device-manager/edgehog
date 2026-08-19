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

defmodule Edgehog.Containers.Deployment.Provisioner.CoreTest do
  @moduledoc """
  Tests for the deployment provisioner Core.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableDeployments
  alias Edgehog.Astarte.Device.AvailableDeployments.DeploymentStatus
  alias Edgehog.Astarte.Device.CreateDeploymentRequest
  alias Edgehog.Containers.Deployment.Provisioner.Core

  describe "Deployment provisioner Core" do
    setup do
      tenant = tenant_fixture()

      deployment =
        [tenant: tenant, release_opts: [containers: 1]]
        |> deployment_fixture()
        |> Ash.load!(:device, tenant: tenant)

      %{
        tenant: tenant,
        deployment: deployment
      }
    end

    test "ready?/1 returns true when the state is a ready one", _context do
      assert Core.ready?(%{state: :started})
      assert Core.ready?(%{state: :stopped})
    end

    test "ready?/1 returns false when the state is not a ready one", _context do
      refute Core.ready?(%{state: :pending})
    end

    test "topic/1 returns the topic on which readiness is broadcast", _context do
      assert Core.topic(%{id: "deployment-id"}) == "deployments:provisioning:deployment-id"
      assert Core.topic("deployment-id") == "deployments:provisioning:deployment-id"
    end

    test "subscribe_topic/1 returns the topic the provisioner subscribes to", _context do
      assert Core.subscribe_topic(%{id: "deployment-id"}) == "deployments:deployment-id"
      assert Core.subscribe_topic("deployment-id") == "deployments:deployment-id"
    end

    test "name/1 returns the via tuple used to register the provisioner", _context do
      assert Core.name(%{id: "deployment-id"}) ==
               {:via, Registry,
                {Edgehog.Containers.Deployment.Provisioner.Registry, "deployment-id"}}
    end

    test "send_to_device/2 sends the create request to the device and marks the deployment as sent",
         context do
      %{deployment: deployment, tenant: tenant} = context

      expect(CreateDeploymentRequest, :send_create_deployment_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateDeploymentRequest.RequestData{
          id: id,
          containers: _containers
        } = data

        assert id == deployment.id

        :ok
      end)

      assert :ok == Core.send_to_device(deployment, tenant: tenant)

      updated = Ash.get!(Edgehog.Containers.Deployment, deployment.id, tenant: tenant)
      assert updated.state == :sent
    end

    test "reconcile/2 updates the deployment when the status is reported by the device",
         context do
      %{deployment: deployment, tenant: tenant} = context

      expect(AvailableDeployments, :get, fn _client, _device_id ->
        {:ok, [%DeploymentStatus{id: deployment.id, status: :stopped}]}
      end)

      assert {:ok, updated} = Core.reconcile(deployment, tenant: tenant)
      assert updated.id == deployment.id
      assert updated.state == :stopped
    end

    test "reconcile/2 returns :not_found when the status is not reported by the device",
         context do
      %{deployment: deployment, tenant: tenant} = context

      expect(AvailableDeployments, :get, fn _client, _device_id ->
        {:ok, []}
      end)

      assert :not_found == Core.reconcile(deployment, tenant: tenant)
    end

    test "temporary_error?/1 correctly recurses on nested errors", _context do
      error = "connection refused"
      assert Core.temporary_error?({:error, error}) == Core.temporary_error?(error)

      error = %{errors: ["unknown error"]}
      assert Core.temporary_error?({:error, error}) == Core.temporary_error?(error)

      error = :other
      assert Core.temporary_error?({:error, error}) == Core.temporary_error?(error)
    end

    test "temporary_error?/1 returns true for \"connection refused\" errors", _context do
      assert Core.temporary_error?("connection refused")
    end

    test "temporary_error?/1 returns true for 5xx responses", _context do
      assert Core.temporary_error?(%Astarte.Client.APIError{
               status: Enum.random(500..599),
               response: "server error"
             })

      assert Core.temporary_error?(%Edgehog.Error.AstarteAPIError{status: Enum.random(500..599)})
    end

    test "temporary_error?/1 returns true for Edgehog.Error.DeviceOffline errors", _context do
      assert Core.temporary_error?(%Edgehog.Error.DeviceOffline{})
    end

    test "temporary_error?/1 returns false for other unspecified errors", _context do
      refute Core.temporary_error?(:other_unspecified_error)
    end
  end
end
