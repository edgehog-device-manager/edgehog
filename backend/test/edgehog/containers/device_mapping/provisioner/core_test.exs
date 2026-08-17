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

defmodule Edgehog.Containers.DeviceMapping.Deployment.Provisioner.CoreTest do
  @moduledoc """
  Tests for the device mapping deployment provisioner Core.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableDeviceMappings
  alias Edgehog.Astarte.Device.AvailableDeviceMappings.DeviceMappingStatus
  alias Edgehog.Astarte.Device.CreateDeviceMappingRequest
  alias Edgehog.Containers.DeviceMapping.Deployment.Provisioner.Core

  describe "DeviceMapping deployment provisioner Core" do
    setup do
      tenant = tenant_fixture()
      device_mapping = device_mapping_fixture(tenant: tenant)

      deployment =
        deployment_fixture(
          tenant: tenant,
          release_opts: [containers: 1, container_params: [device_mappings: [device_mapping.id]]]
        )

      [device_mapping_deployment] =
        deployment
        |> Ash.load!(
          [container_deployments: [device_mapping_deployments: [:device_mapping, :device]]],
          tenant: tenant
        )
        |> Map.get(:container_deployments, [])
        |> Enum.map(&Map.get(&1, :device_mapping_deployments))
        |> List.flatten()

      %{
        tenant: tenant,
        deployment: deployment,
        device_mapping_deployment: device_mapping_deployment
      }
    end

    test "ready?/1 returns true when the state is a ready one", _context do
      assert Core.ready?(%{state: :present})
      assert Core.ready?(%{state: :not_present})
    end

    test "ready?/1 returns false when the state is not a ready one", _context do
      refute Core.ready?(%{state: :created})
    end

    test "topic/1 returns the topic on which readiness is broadcast", _context do
      assert Core.topic(%{id: "device-mapping-deployment-id"}) ==
               "ready:device_mapping_deployments:device-mapping-deployment-id"

      assert Core.topic("device-mapping-deployment-id") ==
               "ready:device_mapping_deployments:device-mapping-deployment-id"
    end

    test "subscribe_topic/1 returns the topic the provisioner subscribes to", _context do
      assert Core.subscribe_topic(%{id: "device-mapping-deployment-id"}) ==
               "device_mapping_deployments:device-mapping-deployment-id"

      assert Core.subscribe_topic("device-mapping-deployment-id") ==
               "device_mapping_deployments:device-mapping-deployment-id"
    end

    test "name/1 returns the via tuple used to register the provisioner", _context do
      assert Core.name(%{id: "device-mapping-deployment-id"}) ==
               {:via, Registry,
                {Edgehog.Containers.DeviceMapping.Deployment.Provisioner.Registry,
                 "device-mapping-deployment-id"}}
    end

    test "send_to_device/2 sends the create request to the device", context do
      %{
        device_mapping_deployment: device_mapping_deployment,
        deployment: deployment,
        tenant: tenant
      } = context

      expect(CreateDeviceMappingRequest, :send_create_device_mapping_request, fn _, _, data ->
        assert data.id == device_mapping_deployment.device_mapping.id
        assert data.deploymentId == deployment.id

        :ok
      end)

      assert :ok ==
               Core.send_to_device(device_mapping_deployment,
                 tenant: tenant,
                 deployment: deployment
               )
    end

    test "reconcile/2 updates the resource when the status is reported by the device", context do
      %{device_mapping_deployment: device_mapping_deployment, tenant: tenant} = context

      expect(AvailableDeviceMappings, :get, fn _client, _device_id ->
        {:ok,
         [
           %DeviceMappingStatus{
             id: device_mapping_deployment.device_mapping.id,
             present: true
           }
         ]}
      end)

      assert {:ok, updated} = Core.reconcile(device_mapping_deployment, tenant: tenant)
      assert updated.id == device_mapping_deployment.id
      assert updated.state == :present
    end

    test "reconcile/2 returns :not_found when the status is not reported by the device",
         context do
      %{device_mapping_deployment: device_mapping_deployment, tenant: tenant} = context

      expect(AvailableDeviceMappings, :get, fn _client, _device_id ->
        {:ok, []}
      end)

      assert :not_found == Core.reconcile(device_mapping_deployment, tenant: tenant)
    end
  end
end
