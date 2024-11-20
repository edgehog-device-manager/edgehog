#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.SendDeploymentUpgradeTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  alias Edgehog.Astarte.Device.AvailableContainers.ContainerStatus
  alias Edgehog.Astarte.Device.AvailableContainersMock
  alias Edgehog.Astarte.Device.AvailableDeployments.DeploymentStatus
  alias Edgehog.Astarte.Device.AvailableDeploymentsMock
  alias Edgehog.Astarte.Device.AvailableImages.ImageStatus
  alias Edgehog.Astarte.Device.AvailableImagesMock
  alias Edgehog.Astarte.Device.AvailableNetworks.NetworkStatus
  alias Edgehog.Astarte.Device.AvailableNetworksMock
  alias Edgehog.Astarte.Device.CreateDeploymentRequestMock
  alias Edgehog.Astarte.Device.DeploymentUpdateMock
  alias Edgehog.Containers
  alias Edgehog.Containers.Deployment

  describe "sendDeploymentUpgrade" do
    setup %{tenant: tenant} do
      release_0_0_1 =
        release_fixture(version: "0.0.1", tenant: tenant)

      release_0_0_2 =
        release_fixture(
          application_id: release_0_0_1.application_id,
          version: "0.0.2",
          tenant: tenant
        )

      deployment_0_0_1 =
        deployment_fixture(release_id: release_0_0_1.id, tenant: tenant)

      %{
        deployment_0_0_1: deployment_0_0_1,
        release_0_0_1: release_0_0_1,
        release_0_0_2: release_0_0_2
      }
    end

    test "correctly sends the deployment request with valid data", args do
      %{deployment_0_0_1: deployment_0_0_1, release_0_0_2: release_0_0_2, tenant: tenant} =
        args

      expect(CreateDeploymentRequestMock, :send_create_deployment_request, fn _, _, _ -> :ok end)

      result =
        [tenant: tenant, deployment: deployment_0_0_1, target: release_0_0_2]
        |> send_deployment_upgrade_mutation()
        |> extract_result!()

      {:ok, %{id: deployment_id}} = AshGraphql.Resource.decode_relay_id(result["id"])

      assert Edgehog.Containers.DeploymentReadyAction
             |> Ash.read_first!(tenant: tenant)
             |> Map.fetch!(:deployment_id) == deployment_id
    end

    test "sends the deployment upgrade once the new deployment reaches :ready state", args do
      %{deployment_0_0_1: deployment_0_0_1, release_0_0_2: release_0_0_2, tenant: tenant} =
        args

      expect(CreateDeploymentRequestMock, :send_create_deployment_request, fn _, _, _ -> :ok end)
      expect(DeploymentUpdateMock, :update, fn _, _, _ -> :ok end)

      result =
        [tenant: tenant, deployment: deployment_0_0_1, target: release_0_0_2]
        |> send_deployment_upgrade_mutation()
        |> extract_result!()

      {:ok, %{id: deployment_id}} = AshGraphql.Resource.decode_relay_id(result["id"])

      deployment = Ash.get!(Deployment, deployment_id, tenant: tenant)
      set_resource_expectations([deployment_0_0_1, deployment])

      Containers.deployment_update_status!(deployment)
    end

    test "fails if the deployments do not belong to the same application", args do
      %{deployment_0_0_1: deployment_0_0_1, release_0_0_2: release_0_0_2, tenant: tenant} =
        args

      release_0_0_2_b = release_fixture(version: release_0_0_2.version, tenant: tenant)

      [tenant: tenant, deployment: deployment_0_0_1, target: release_0_0_2_b]
      |> send_deployment_upgrade_mutation()
      |> extract_error!()
    end

    test "fails if the second deployment does not have a greater version than the first", args do
      %{release_0_0_1: release_0_0_1, release_0_0_2: release_0_0_2, tenant: tenant} =
        args

      deployment_0_0_2 = deployment_fixture(release_id: release_0_0_2.id, tenant: tenant)

      [tenant: tenant, deployment: deployment_0_0_2, target: release_0_0_1]
      |> send_deployment_upgrade_mutation()
      |> extract_error!()
    end
  end

  defp send_deployment_upgrade_mutation(opts) do
    default_document = """
    mutation UpgradeDeployment($id: ID!, $input: UpgradeDeploymentInput!) {
      upgradeDeployment(id: $id, input: $input) {
        result {
          id
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)
    target = Keyword.fetch!(opts, :target)

    input = %{
      "target" => AshGraphql.Resource.encode_relay_id(target)
    }

    variables = %{
      "id" => AshGraphql.Resource.encode_relay_id(deployment),
      "input" => input
    }

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    refute :errors in Map.keys(result)

    assert %{
             data: %{
               "upgradeDeployment" => %{
                 "result" => result
               }
             }
           } = result

    assert result != nil

    result
  end

  defp extract_error!(result) do
    assert %{
             data: %{"upgradeDeployment" => nil},
             errors: [error]
           } = result

    error
  end

  defp set_resource_expectations(deployments) do
    deployments =
      Enum.map(deployments, &Ash.load!(&1, release: [containers: [:image, :networks]]))

    containers =
      deployments
      |> Enum.map(& &1.release)
      |> Enum.flat_map(& &1.containers)
      |> Enum.uniq_by(& &1.id)

    available_containers = Enum.map(containers, &%ContainerStatus{id: &1.id, status: "Created"})

    available_images =
      containers
      |> Enum.flat_map(& &1.image)
      |> Enum.map(&%ImageStatus{id: &1.id, pulled: false})
      |> Enum.uniq()

    available_networks =
      containers
      |> Enum.flat_map(& &1.network)
      |> Enum.map(&%NetworkStatus{id: &1.id, created: false})
      |> Enum.uniq()

    available_deployments =
      Enum.map(deployments, &%DeploymentStatus{id: &1.id, status: :stopped})

    expect(AvailableImagesMock, :get, fn _, _ -> {:ok, available_images} end)
    expect(AvailableNetworksMock, :get, fn _, _ -> {:ok, available_networks} end)
    expect(AvailableContainersMock, :get, fn _, _ -> {:ok, available_containers} end)
    expect(AvailableDeploymentsMock, :get, fn _, _ -> {:ok, available_deployments} end)
  end
end
