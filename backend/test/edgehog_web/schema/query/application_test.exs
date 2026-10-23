#
# This file is part of Edgehog.
#
# Copyright 2024-2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.ApplicationsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  test "can access releases through a relationship", %{tenant: tenant} do
    app = application_fixture(tenant: tenant)

    releases = [
      release_fixture(application_id: app.id, tenant: tenant),
      release_fixture(application_id: app.id, tenant: tenant)
    ]

    releases = Enum.sort_by(releases, & &1.version)

    _extra_release = release_fixture(tenant: tenant)

    id = AshGraphql.Resource.encode_relay_id(app)

    application =
      [tenant: tenant, id: id]
      |> get_application()
      |> extract_result!()

    results =
      application
      |> get_in(["application", "releases", "edges"])
      |> Enum.map(& &1["node"])
      |> Enum.sort_by(& &1["version"])

    assert Enum.count(results) == Enum.count(releases)

    for {release, result} <- Enum.zip(releases, results) do
      assert result["version"] == release.version
    end
  end

  test "can access deployments of an application through a relationship", %{tenant: tenant} do
    app = application_fixture(tenant: tenant)

    release =
      release_fixture(
        application_id: app.id,
        version: "1.2.0",
        system_models: 1,
        tenant: tenant
      )

    device = device_fixture_compatible_with_release(release_id: release.id, tenant: tenant)

    deployment =
      deployment_fixture(device_id: device.id, release_id: release.id, tenant: tenant)

    document =
      """
      query ($id: ID!) {
        application(id: $id) {
          releases {
            edges {
              node {
                id
                version
              }
            }
          }
          deployments {
            edges {
              node {
                id
                device {
                  id
                }
                release {
                  version
                }
              }
            }
          }
        }
      }
      """

    id = AshGraphql.Resource.encode_relay_id(app)

    application =
      [tenant: tenant, id: id, document: document]
      |> get_application()
      |> extract_result!()

    release_nodes =
      application
      |> get_in(["application", "releases", "edges"])
      |> Enum.map(& &1["node"])

    assert [%{"id" => plain_release_id, "version" => "1.2.0"}] = release_nodes
    assert plain_release_id == AshGraphql.Resource.encode_relay_id(release)

    deployment_nodes =
      application
      |> get_in(["application", "deployments", "edges"])
      |> Enum.map(& &1["node"])

    assert [
             %{
               "id" => deployment_id,
               "device" => %{"id" => device_id},
               "release" => %{"version" => "1.2.0"}
             }
           ] = deployment_nodes

    assert deployment_id == AshGraphql.Resource.encode_relay_id(deployment)
    assert device_id == AshGraphql.Resource.encode_relay_id(device)
  end

  defp get_application(opts) do
    default_document =
      """
      query ($id: ID!) {
        application(id: $id) {
          name
          description
          releases {
            edges {
              node {
                version
              }
            }
          }
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    id = Keyword.fetch!(opts, :id)
    variables = %{"id" => id}

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  def extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: data} = result
    assert data

    data
  end
end
