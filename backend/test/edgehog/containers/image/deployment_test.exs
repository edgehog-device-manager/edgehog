#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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
    test "links up to container deployments", %{tenant: tenant, image: image} do
      release1 =
        release_fixture(tenant: tenant, containers: 1, container_params: [image_id: image.id])

      release2 =
        release_fixture(tenant: tenant, containers: 1, container_params: [image_id: image.id])

      device = device_fixture(tenant: tenant)

      deployment1 =
        deployment_fixture(tenant: tenant, device_id: device.id, release_id: release1.id)

      deployment2 =
        deployment_fixture(tenant: tenant, device_id: device.id, release_id: release2.id)

      [container_deployment1] =
        deployment1
        |> Ash.load!(container_deployments: [:image_deployment])
        |> Map.get(:container_deployments)

      [container_deployment2] =
        deployment2
        |> Ash.load!(container_deployments: [:image_deployment])
        |> Map.get(:container_deployments)

      assert container_deployment1.image_deployment == container_deployment2.image_deployment
    end
  end
end
