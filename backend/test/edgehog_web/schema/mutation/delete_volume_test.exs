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

defmodule EdgehogWeb.Schema.Mutation.DeleteVolumeTest do
  @moduledoc false

  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  alias Edgehog.Containers.Volume

  require Ash.Query

  describe "deleteVolume mutation" do
    setup %{tenant: tenant} do
      volume = volume_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(volume)

      {:ok, volume: volume, id: id}
    end

    test "deletes existing volume", %{
      tenant: tenant,
      volume: volume,
      id: id
    } do
      volume_data =
        [tenant: tenant, id: id]
        |> delete_volume_mutation()
        |> extract_result!()

      assert volume_data["id"] == id
      assert volume_data["label"] == volume.label

      refute Volume
             |> Ash.Query.filter(id == ^volume.id)
             |> Ash.Query.set_tenant(tenant)
             |> Ash.exists?()
    end

    test "fails with non-existing volume", %{tenant: tenant} do
      id = non_existing_volume_id(tenant)

      error = [tenant: tenant, id: id] |> delete_volume_mutation() |> extract_error!()

      assert %{
               path: ["deleteVolume"],
               fields: [:id],
               code: "not_found",
               message: "could not be found"
             } = error
    end

    test "fails if the volume is used by any container", %{
      tenant: tenant,
      volume: volume,
      id: id
    } do
      container = container_fixture(tenant: tenant)

      params = %{container_id: container.id, volume_id: volume.id, target: "/data"}
      Ash.create!(Edgehog.Containers.ContainerVolume, params, tenant: tenant)

      result = delete_volume_mutation(tenant: tenant, id: id)

      assert %{fields: [:id], message: "would leave records behind"} = extract_error!(result)
    end
  end

  defp delete_volume_mutation(opts) do
    default_document = """
    mutation DeleteVolume($id: ID!) {
      deleteVolume(id: $id) {
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
             data: %{"deleteVolume" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteVolume" => %{
                 "result" => volume
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert volume

    volume
  end

  defp non_existing_volume_id(tenant) do
    fixture = volume_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture, tenant: tenant)

    id
  end
end
