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

defmodule EdgehogWeb.Schema.Query.ReleaseTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  alias Edgehog.Containers.ContainerNetwork
  alias Edgehog.Containers.ReleaseContainers

  test "can access containers and netowkrs trough relationship", %{tenant: tenant} do
    app = application_fixture(tenant: tenant)
    release = release_fixture(application_id: app.id, tenant: tenant)

    container = container_fixture(tenant: tenant)
    network = network_fixture(tenant: tenant)

    params = %{container_id: container.id, release_id: release.id}
    Ash.create!(ReleaseContainers, params, tenant: tenant)

    params = %{container_id: container.id, network_id: network.id}
    Ash.create!(ContainerNetwork, params, tenant: tenant)

    id = AshGraphql.Resource.encode_relay_id(release)

    release = [tenant: tenant, id: id] |> get_release() |> extract_result!()

    assert get_in(release, ["release", "id"]) == id

    container_result =
      release
      |> get_in(["release", "containers", "edges"])
      |> Enum.map(& &1["node"])
      |> hd()

    assert container_result["id"] == AshGraphql.Resource.encode_relay_id(container)

    network_result =
      container_result |> get_in(["networks", "edges"]) |> Enum.map(& &1["node"]) |> hd()

    assert network_result["id"] == AshGraphql.Resource.encode_relay_id(network)
  end

  defp get_release(opts) do
    default_document =
      """
      query ($id: ID!) {
        release(id: $id) {
          id
          containers {
            edges {
              node {
                id
                networks {
                  edges {
                    node {
                      id
                    }
                  }
                }
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

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: data} = result
    assert data != nil

    data
  end
end
