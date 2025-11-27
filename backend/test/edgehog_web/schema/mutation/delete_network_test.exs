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

defmodule EdgehogWeb.Schema.Mutation.DeleteNetworkTest do
  @moduledoc false

  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  alias Edgehog.Containers.Network

  require Ash.Query

  describe "deleteNetwork mutation" do
    setup %{tenant: tenant} do
      network = network_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(network)

      {:ok, network: network, id: id}
    end

    test "deletes existing network", %{
      tenant: tenant,
      network: network,
      id: id
    } do
      network_data =
        [tenant: tenant, id: id]
        |> delete_network_mutation()
        |> extract_result!()

      assert network_data["id"] == id
      assert network_data["label"] == network.label

      refute Network
             |> Ash.Query.filter(id == ^network.id)
             |> Ash.Query.set_tenant(tenant)
             |> Ash.exists?()
    end

    test "fails with non-existing network", %{tenant: tenant} do
      id = non_existing_network_id(tenant)

      error = [tenant: tenant, id: id] |> delete_network_mutation() |> extract_error!()

      assert %{
               path: ["deleteNetwork"],
               fields: [:id],
               code: "not_found",
               message: "could not be found"
             } = error
    end

    test "fails if the network is used by any container", %{
      tenant: tenant,
      network: network,
      id: id
    } do
      container = container_fixture(tenant: tenant)

      params = %{container_id: container.id, network_id: network.id}
      Ash.create!(Edgehog.Containers.ContainerNetwork, params, tenant: tenant)

      result = delete_network_mutation(tenant: tenant, id: id)

      assert %{fields: [:id], message: "would leave records behind"} = extract_error!(result)
    end
  end

  defp delete_network_mutation(opts) do
    default_document = """
    mutation DeleteNetwork($id: ID!) {
      deleteNetwork(id: $id) {
        result {
          id
          label
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    document = Keyword.get(opts, :document, default_document)
    variables = %{"id" => id}
    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"deleteNetwork" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteNetwork" => %{
                 "result" => network
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert network

    network
  end

  defp non_existing_network_id(tenant) do
    fixture = network_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture, tenant: tenant)

    id
  end
end
