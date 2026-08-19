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

defmodule Edgehog.Containers.Network.Deployment.Provisioner.CoreTest do
  @moduledoc """
  Tests for the network deployment provisioner Core.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableNetworks
  alias Edgehog.Astarte.Device.AvailableNetworks.NetworkStatus
  alias Edgehog.Astarte.Device.CreateNetworkRequest
  alias Edgehog.Containers.Network.Deployment.Provisioner.Core

  describe "Network deployment provisioner Core" do
    setup do
      tenant = tenant_fixture()
      network = network_fixture(tenant: tenant)

      deployment =
        deployment_fixture(
          tenant: tenant,
          release_opts: [containers: 1, container_params: [networks: [network.id]]]
        )

      [network_deployment] =
        deployment
        |> Ash.load!(
          [container_deployments: [network_deployments: [network: [], device: []]]],
          tenant: tenant
        )
        |> Map.get(:container_deployments, [])
        |> Enum.map(&Map.get(&1, :network_deployments))
        |> List.flatten()

      %{
        tenant: tenant,
        deployment: deployment,
        network_deployment: network_deployment
      }
    end

    test "ready?/1 returns true when the state is a ready one", _context do
      assert Core.ready?(%{state: :available})
      assert Core.ready?(%{state: :unavailable})
    end

    test "ready?/1 returns false when the state is not a ready one", _context do
      refute Core.ready?(%{state: :created})
    end

    test "topic/1 returns the topic on which readiness is broadcast", _context do
      assert Core.topic(%{id: "network-deployment-id"}) ==
               "ready:network_deployments:network-deployment-id"

      assert Core.topic("network-deployment-id") ==
               "ready:network_deployments:network-deployment-id"
    end

    test "subscribe_topic/1 returns the topic the provisioner subscribes to", _context do
      assert Core.subscribe_topic(%{id: "network-deployment-id"}) ==
               "network_deployments:network-deployment-id"

      assert Core.subscribe_topic("network-deployment-id") ==
               "network_deployments:network-deployment-id"
    end

    test "name/1 returns the via tuple used to register the provisioner", _context do
      assert Core.name(%{id: "network-deployment-id"}) ==
               {:via, Registry,
                {Edgehog.Containers.Network.Deployment.Provisioner.Registry,
                 "network-deployment-id"}}
    end

    test "send_to_device/2 sends the create request to the device", context do
      %{
        network_deployment: network_deployment,
        deployment: deployment,
        tenant: tenant
      } = context

      expect(CreateNetworkRequest, :send_create_network_request, fn _, _, data ->
        assert data.id == network_deployment.network.id
        assert data.deploymentId == deployment.id

        :ok
      end)

      assert :ok ==
               Core.send_to_device(network_deployment,
                 tenant: tenant,
                 deployment: deployment
               )
    end

    test "reconcile/2 updates the resource when the status is reported by the device", context do
      %{network_deployment: network_deployment, tenant: tenant} = context

      expect(AvailableNetworks, :get, fn _client, _device_id ->
        {:ok, [%NetworkStatus{id: network_deployment.network.id, created: true}]}
      end)

      assert {:ok, updated} = Core.reconcile(network_deployment, tenant: tenant)
      assert updated.id == network_deployment.id
      assert updated.state == :available
    end

    test "reconcile/2 returns :not_found when the status is not reported by the device",
         context do
      %{network_deployment: network_deployment, tenant: tenant} = context

      expect(AvailableNetworks, :get, fn _client, _device_id ->
        {:ok, []}
      end)

      assert :not_found == Core.reconcile(network_deployment, tenant: tenant)
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
