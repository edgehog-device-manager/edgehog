#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.UpdateDeploymentDelete do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  alias Edgehog.Astarte.Device.DeploymentCommandMock

  describe "deleteDeployment mutation tests" do
    test "delete on an existing deployment", %{tenant: tenant} do
      # we need to set the state of deployment in one of ready states so the action validation passes
      {:ok, deployment} =
        [tenant: tenant]
        |> deployment_fixture()
        |> Edgehog.Containers.mark_deployment_as_stopped(tenant: tenant)

      expect(DeploymentCommandMock, :send_deployment_command, 1, fn _, _, _ -> :ok end)

      [tenant: tenant, deployment: deployment]
      |> send_delete_deployment_mutation()
      |> extract_result!()
    end

    test "delete on a non existing deployment complains", %{tenant: tenant} do
      deployment = deployment_fixture(tenant: tenant)

      assert :ok = deployment |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy!()

      [tenant: tenant, deployment: deployment]
      |> send_delete_deployment_mutation()
      |> extract_error!()
    end

    test "delete on a non ready deployment complains", %{tenant: tenant} do
      # deployment is not ready because it is in :pending state
      deployment = deployment_fixture(tenant: tenant)

      [tenant: tenant, deployment: deployment]
      |> send_delete_deployment_mutation()
      |> extract_error!()
    end
  end

  defp send_delete_deployment_mutation(opts) do
    default_document = """
    mutation DeleteDeployment($input: ID!) {
      deleteDeployment(id: $input) {
        result {
          id
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {deployment, opts} = Keyword.pop!(opts, :deployment)

    input = AshGraphql.Resource.encode_relay_id(deployment)

    variables = %{
      "input" => input
    }

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    assert %{
             data: %{
               "deleteDeployment" => %{
                 "result" => deployment
               }
             }
           } = result

    refute :errors in Map.keys(result)
    assert deployment

    deployment
  end

  defp extract_error!(result) do
    assert %{
             data: %{
               "deleteDeployment" => nil
             },
             errors: [error]
           } = result

    error
  end
end
