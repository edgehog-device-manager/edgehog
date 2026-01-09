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

defmodule Edgehog.Containers.DeploymentTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Image

  setup do
    tenant = tenant_fixture()
    deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

    %{tenant: tenant, deployment: deployment}
  end

  test "destroy_if_dangling removes the container_deployment only if danlging", %{
    deployment: deployment
  } do
    deployment = Ash.load!(deployment, :container_deployments)
    [container_deployment] = deployment.container_deployments

    assert {:error, _} =
             container_deployment
             |> Ash.Changeset.for_destroy(:destroy_if_dangling)
             |> Ash.destroy()

    Ash.destroy!(deployment)

    assert :ok = Ash.destroy(container_deployment)
  end

  test "destroy_and_gc garbage collects", %{
    deployment: deployment
  } do
    deployment =
      Ash.load!(deployment,
        container_deployments: [
          :image_deployment,
          :volume_deployments,
          :network_deployments,
          :device_mapping_deployments
        ]
      )

    [container_deployment] = deployment.container_deployments
    image_deployment = container_deployment.image_deployment

    deployment
    |> Ash.Changeset.for_destroy(:destroy_and_gc)
    |> Ash.destroy!()

    assert {:error, _} = Ash.get(Image.Deployment, image_deployment.id)
    assert {:error, _} = Ash.get(Container.Deployment, container_deployment.id)
  end
end
