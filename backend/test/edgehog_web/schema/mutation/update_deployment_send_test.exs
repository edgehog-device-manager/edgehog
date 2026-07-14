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

defmodule EdgehogWeb.Schema.Mutation.UpdateDeploymentSendTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  alias Edgehog.Containers.Deployment.Supervisor, as: DeploymentSupervisor

  describe "startDeployment mutation tests" do
    test "start on an existing deployment", %{tenant: tenant} do
      # we need to set the state of deployment in one of ready states so the action validation passes
      deployment = deployment_fixture(release_opts: [containers: 1], tenant: tenant)

      expect(DeploymentSupervisor, :supervise, fn _, _ -> :ok end)

      result =
        [tenant: tenant, deployment: deployment]
        |> send_deployment_mutation()
        |> extract_result!()

      assert AshGraphql.Resource.encode_relay_id(deployment) == result["id"]
    end
  end

  defp send_deployment_mutation(opts) do
    default_document = """
    mutation SendDeployment($id: ID!) {
      sendDeployment(id: $id) {
        result {
          id
          state
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {deployment, opts} = Keyword.pop!(opts, :deployment)

    variables = %{
      "id" => AshGraphql.Resource.encode_relay_id(deployment)
    }

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  def extract_result!(result) do
    assert %{
             data: %{
               "sendDeployment" => %{
                 "result" => deployment
               }
             }
           } = result

    refute :errors in Map.keys(result)
    assert deployment

    deployment
  end
end
