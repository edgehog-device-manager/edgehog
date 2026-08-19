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

defmodule Edgehog.Containers.Container.Deployment.Provisioner.CoreTest do
  @moduledoc """
  Tests for the container deployment provisioner Core.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableContainers
  alias Edgehog.Astarte.Device.AvailableContainers.ContainerStatus
  alias Edgehog.Astarte.Device.CreateContainerRequest
  alias Edgehog.Containers.Container.Deployment.Provisioner.Core

  describe "Container deployment provisioner Core" do
    setup do
      tenant = tenant_fixture()

      deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

      [container_deployment] =
        deployment
        |> Ash.load!([container_deployments: [:container, :device]], tenant: tenant)
        |> Map.get(:container_deployments, [])

      %{
        tenant: tenant,
        deployment: deployment,
        container_deployment: container_deployment
      }
    end

    test "ready?/1 returns true when the state is a ready one", _context do
      assert Core.ready?(%{state: :received})
      assert Core.ready?(%{state: :device_created})
      assert Core.ready?(%{state: :stopped})
      assert Core.ready?(%{state: :running})
    end

    test "ready?/1 returns false when the state is not a ready one", _context do
      refute Core.ready?(%{state: :created})
      refute Core.ready?(%{state: :sent})
    end

    test "topic/1 returns the topic on which readiness is broadcast", _context do
      assert Core.topic(%{id: "container-deployment-id"}) ==
               "container_deployments:provisioning:container-deployment-id"

      assert Core.topic("container-deployment-id") ==
               "container_deployments:provisioning:container-deployment-id"
    end

    test "subscribe_topic/1 returns the topic the provisioner subscribes to", _context do
      assert Core.subscribe_topic(%{id: "container-deployment-id"}) ==
               "container_deployments:container-deployment-id"

      assert Core.subscribe_topic("container-deployment-id") ==
               "container_deployments:container-deployment-id"
    end

    test "name/1 returns the via tuple used to register the provisioner", _context do
      assert Core.name(%{id: "container-deployment-id"}) ==
               {:via, Registry,
                {Edgehog.Containers.Container.Deployment.Provisioner.Registry,
                 "container-deployment-id"}}
    end

    test "send_to_device/2 sends the create request to the device", context do
      %{
        container_deployment: container_deployment,
        deployment: deployment,
        tenant: tenant
      } = context

      expect(CreateContainerRequest, :send_create_container_request, fn _, _, data ->
        assert data.id == container_deployment.container.id
        assert data.deploymentId == deployment.id

        :ok
      end)

      assert :ok ==
               Core.send_to_device(container_deployment,
                 tenant: tenant,
                 deployment: deployment
               )
    end

    test "reconcile/2 updates the resource when the status is reported by the device", context do
      %{container_deployment: container_deployment, tenant: tenant} = context

      expect(AvailableContainers, :get, fn _client, _device_id ->
        {:ok, [%ContainerStatus{id: container_deployment.container.id, status: "Created"}]}
      end)

      assert {:ok, updated} = Core.reconcile(container_deployment, tenant: tenant)
      assert updated.id == container_deployment.id
      assert updated.state == :device_created
    end

    test "reconcile/2 returns :not_found when the status is not reported by the device",
         context do
      %{container_deployment: container_deployment, tenant: tenant} = context

      expect(AvailableContainers, :get, fn _client, _device_id ->
        {:ok, []}
      end)

      assert :not_found == Core.reconcile(container_deployment, tenant: tenant)
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
