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

defmodule Edgehog.Containers.Volume.Deployment.Provisioner.CoreTest do
  @moduledoc """
  Tests for the volume deployment provisioner Core.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableVolumes
  alias Edgehog.Astarte.Device.AvailableVolumes.VolumeStatus
  alias Edgehog.Astarte.Device.CreateVolumeRequest
  alias Edgehog.Containers.Volume.Deployment.Provisioner.Core

  describe "Volume deployment provisioner Core" do
    setup do
      tenant = tenant_fixture()

      deployment =
        deployment_fixture(
          tenant: tenant,
          release_opts: [containers: 1, container_params: [volumes: 1]]
        )

      volume_deployment =
        deployment
        |> Ash.load!(container_deployments: [volume_deployments: [:volume, :device]])
        |> Map.get(:container_deployments, [])
        |> List.first()
        |> Map.get(:volume_deployments, [])
        |> List.first()

      %{
        tenant: tenant,
        deployment: deployment,
        volume_deployment: volume_deployment
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
      assert Core.topic(%{id: "volume-deployment-id"}) ==
               "ready:volume_deployments:volume-deployment-id"

      assert Core.topic("volume-deployment-id") == "ready:volume_deployments:volume-deployment-id"
    end

    test "subscribe_topic/1 returns the topic the provisioner subscribes to", _context do
      assert Core.subscribe_topic(%{id: "volume-deployment-id"}) ==
               "volume_deployments:volume-deployment-id"

      assert Core.subscribe_topic("volume-deployment-id") ==
               "volume_deployments:volume-deployment-id"
    end

    test "name/1 returns the via tuple used to register the provisioner", _context do
      assert Core.name(%{id: "volume-deployment-id"}) ==
               {:via, Registry,
                {Edgehog.Containers.Volume.Deployment.Provisioner.Registry,
                 "volume-deployment-id"}}
    end

    test "send_to_device/2 sends the create request to the device", context do
      %{
        volume_deployment: volume_deployment,
        deployment: deployment,
        tenant: tenant
      } = context

      expect(CreateVolumeRequest, :send_create_volume_request, fn _, _, data ->
        assert data.id == volume_deployment.volume.id
        assert data.deploymentId == deployment.id

        :ok
      end)

      assert :ok ==
               Core.send_to_device(volume_deployment,
                 tenant: tenant,
                 deployment: deployment
               )
    end

    test "reconcile/2 updates the resource when the status is reported by the device", context do
      %{volume_deployment: volume_deployment, tenant: tenant} = context

      expect(AvailableVolumes, :get, fn _client, _device_id ->
        {:ok, [%VolumeStatus{id: volume_deployment.volume.id, created: true}]}
      end)

      assert {:ok, updated} = Core.reconcile(volume_deployment, tenant: tenant)
      assert updated.id == volume_deployment.id
      assert updated.state == :available
    end

    test "reconcile/2 returns :not_found when the status is not reported by the device",
         context do
      %{volume_deployment: volume_deployment, tenant: tenant} = context

      expect(AvailableVolumes, :get, fn _client, _device_id ->
        {:ok, []}
      end)

      assert :not_found == Core.reconcile(volume_deployment, tenant: tenant)
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
