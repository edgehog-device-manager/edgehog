#
# This file is part of Edgehog.
#
# Copyright 2025-2026 SECO Mind Srl
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

defmodule Edgehog.Containers.Image.DeploymentTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  setup do
    tenant = tenant_fixture()
    image = image_fixture(tenant: tenant)

    %{tenant: tenant, image: image}
  end

  describe "Image deployment" do
    test "reuses copied image deployment across containers in the same release", %{
      tenant: tenant,
      image: image
    } do
      release =
        release_fixture(tenant: tenant, containers: 2, container_params: [image: image])

      device = device_fixture(tenant: tenant)

      deployment =
        deployment_fixture(tenant: tenant, device_id: device.id, release_id: release.id)

      [container_deployment1, container_deployment2] =
        deployment
        |> Ash.load!(container_deployments: [image_deployment: [:image]])
        |> Map.get(:container_deployments)

      assert container_deployment1.image_deployment.id ==
               container_deployment2.image_deployment.id

      assert container_deployment1.image_deployment.image_id != image.id
      assert container_deployment1.image_deployment.image.reference == image.reference
    end

    test "reuses unchanged image deployment across release deployments on the same device", %{
      tenant: tenant,
      image: image
    } do
      release1 =
        release_fixture(tenant: tenant, containers: 1, container_params: [image: image])

      release2 =
        release_fixture(tenant: tenant, containers: 1, container_params: [image: image])

      device = device_fixture(tenant: tenant)

      deployment1 =
        deployment_fixture(tenant: tenant, device_id: device.id, release_id: release1.id)

      deployment2 =
        deployment_fixture(tenant: tenant, device_id: device.id, release_id: release2.id)

      [container_deployment1] =
        deployment1
        |> Ash.load!(container_deployments: [image_deployment: [:image]])
        |> Map.get(:container_deployments)

      [container_deployment2] =
        deployment2
        |> Ash.load!(container_deployments: [image_deployment: [:image]])
        |> Map.get(:container_deployments)

      assert container_deployment1.image_deployment.id ==
               container_deployment2.image_deployment.id

      assert container_deployment1.image_deployment.image_id != image.id
      assert container_deployment1.image_deployment.image.reference == image.reference
    end

    test "snapshots registry_auth and provenance onto deployed image copy", %{tenant: tenant} do
      credentials =
        [tenant: tenant]
        |> image_credentials_fixture()
        |> Ash.load!(:base64_json, tenant: tenant)

      image =
        image_fixture(
          tenant: tenant,
          image_credentials_id: credentials.id
        )

      release =
        release_fixture(tenant: tenant, containers: 1, container_params: [image: image])

      device = device_fixture(tenant: tenant)

      deployment =
        deployment_fixture(tenant: tenant, device_id: device.id, release_id: release.id)

      [container_deployment] =
        deployment
        |> Ash.load!(container_deployments: [image_deployment: [:image]])
        |> Map.get(:container_deployments)

      deployed_image = container_deployment.image_deployment.image

      assert deployed_image.source_image_id == image.id
      assert deployed_image.registry_auth == credentials.base64_json
      assert deployed_image.image_credentials_id == credentials.id

      # Updating the credentials does not alter the snapshotted registry_auth on the deployed copy
      credentials
      |> Ash.Changeset.for_update(:update, %{password: "updated-password"}, tenant: tenant)
      |> Ash.update!(tenant: tenant)

      reloaded_deployed_image =
        Ash.get!(Edgehog.Containers.Image, deployed_image.id, tenant: tenant)

      assert reloaded_deployed_image.registry_auth == credentials.base64_json
    end
  end
end
