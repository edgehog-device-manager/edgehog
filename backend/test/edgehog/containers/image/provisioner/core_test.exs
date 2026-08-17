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

defmodule Edgehog.Containers.Image.Deployment.Provisioner.CoreTest do
  @moduledoc """
  Tests for the image deployment provisioner Core.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableImages
  alias Edgehog.Astarte.Device.AvailableImages.ImageStatus
  alias Edgehog.Astarte.Device.CreateImageRequest
  alias Edgehog.Containers.Image.Deployment.Provisioner.Core

  describe "Image deployment provisioner Core" do
    setup do
      tenant = tenant_fixture()

      deployment =
        deployment_fixture(
          tenant: tenant,
          release_opts: [containers: 1]
        )

      [image_deployment] =
        deployment
        |> Ash.load!([container_deployments: [image_deployment: [:image, :device]]],
          tenant: tenant
        )
        |> Map.get(:container_deployments, [])
        |> Enum.map(&Map.get(&1, :image_deployment))

      %{
        tenant: tenant,
        deployment: deployment,
        image_deployment: image_deployment
      }
    end

    test "ready?/1 returns true when the state is a ready one", _context do
      assert Core.ready?(%{state: :pulled})
      assert Core.ready?(%{state: :unpulled})
    end

    test "ready?/1 returns false when the state is not a ready one", _context do
      refute Core.ready?(%{state: :not_present})
    end

    test "topic/1 returns the topic on which readiness is broadcast", _context do
      assert Core.topic(%{id: "image-id"}) == "ready:image_deployments:image-id"
      assert Core.topic("image-id") == "ready:image_deployments:image-id"
    end

    test "subscribe_topic/1 returns the topic the provisioner subscribes to", _context do
      assert Core.subscribe_topic(%{id: "image-id"}) == "image_deployments:image-id"
      assert Core.subscribe_topic("image-id") == "image_deployments:image-id"
    end

    test "name/1 returns the via tuple used to register the provisioner", _context do
      assert Core.name(%{id: "image-id"}) ==
               {:via, Registry,
                {Edgehog.Containers.Image.Deployment.Provisioner.Registry, "image-id"}}
    end

    test "send_to_device/2 sends the create request to the device", context do
      %{
        image_deployment: image_deployment,
        deployment: deployment,
        tenant: tenant
      } = context

      expect(CreateImageRequest, :send_create_image_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateImageRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          reference: reference
        } = data

        assert id == image_deployment.image.id
        assert deployment_id == deployment.id
        assert reference == image_deployment.image.reference

        :ok
      end)

      assert :ok ==
               Core.send_to_device(image_deployment, tenant: tenant, deployment: deployment)
    end

    test "reconcile/2 updates the resource when the status is reported by the device", context do
      %{image_deployment: image_deployment, tenant: tenant} = context

      expect(AvailableImages, :get, fn _client, _device_id ->
        {:ok, [%ImageStatus{id: image_deployment.image.id, pulled: false}]}
      end)

      assert {:ok, updated} = Core.reconcile(image_deployment, tenant: tenant)
      assert updated.id == image_deployment.id
      assert updated.state == :unpulled
    end

    test "reconcile/2 returns :not_found when the status is not reported by the device",
         context do
      %{image_deployment: image_deployment, tenant: tenant} = context

      expect(AvailableImages, :get, fn _client, _device_id ->
        {:ok, []}
      end)

      assert :not_found == Core.reconcile(image_deployment, tenant: tenant)
    end
  end
end
