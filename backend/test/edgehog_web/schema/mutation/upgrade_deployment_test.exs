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

defmodule EdgehogWeb.Schema.Mutation.UpgradeDeploymentTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  alias Edgehog.Containers.Deployment

  test "upgradeDeployment applies configs to the new deployment", %{tenant: tenant} do
    deployment = ready_deployment_fixture(tenant: tenant)

    container =
      [tenant: tenant, file_mounts: [%{mountpoint: "/etc/app.conf", required: true}]]
      |> container_fixture()
      |> Ash.load!(:file_mounts)

    %{file_mounts: [file_mount]} = container

    target_release =
      release_fixture(
        tenant: tenant,
        application_id: deployment.release.application_id,
        version: "0.0.2",
        container_ids: [container.id]
      )

    expect(Deployment.Orchestrator, :conduct, fn _, _ -> :ok end)

    result =
      [
        tenant: tenant,
        id: AshGraphql.Resource.encode_relay_id(deployment),
        target: AshGraphql.Resource.encode_relay_id(target_release),
        configs: [
          %{
            "containerId" => AshGraphql.Resource.encode_relay_id(container),
            "env" => [%{"key" => "FOO", "value" => "bar"}],
            "fileBinds" => [
              %{"fileMountId" => AshGraphql.Resource.encode_relay_id(file_mount)}
            ]
          }
        ]
      ]
      |> upgrade_deployment_mutation()
      |> extract_result!()

    assert %{"id" => deployment_id} = result

    {:ok, %{id: decoded_id}} = AshGraphql.Resource.decode_relay_id(deployment_id)

    new_deployment =
      Edgehog.Containers.Deployment
      |> Ash.get!(decoded_id, tenant: tenant)
      |> Ash.load!([container_deployments: [:file_binds]], tenant: tenant)

    assert new_deployment.release_id == target_release.id
    assert length(new_deployment.container_deployments) == 1

    [container_deployment] = new_deployment.container_deployments
    assert container_deployment.env == [%{key: "FOO", value: "bar"}]

    assert length(container_deployment.file_binds) == 1

    [file_bind] = container_deployment.file_binds
    assert file_bind.file_mount_id == file_mount.id
  end

  defp ready_deployment_fixture(tenant: tenant) do
    application = application_fixture(tenant: tenant)

    release =
      release_fixture(
        tenant: tenant,
        application_id: application.id,
        version: "0.0.1",
        containers: 1
      )

    [tenant: tenant, release_id: release.id]
    |> deployment_fixture()
    |> make_deployment_ready!(tenant)
    |> Ash.load!(:release, tenant: tenant)
  end

  defp upgrade_deployment_mutation(opts) do
    default_document = """
    mutation UpgradeDeployment($id: ID!, $input: UpgradeDeploymentInput!) {
      upgradeDeployment(id: $id, input: $input) {
        result {
          id
        }
        errors {
          message
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)
    {target, opts} = Keyword.pop!(opts, :target)
    {configs, _opts} = Keyword.pop(opts, :configs)

    input = %{"target" => target, "configs" => configs}
    variables = %{"id" => id, "input" => input}
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{data: %{"upgradeDeployment" => %{"result" => deployment}}} = result

    assert deployment

    deployment
  end
end
