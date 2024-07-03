#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.DeleteUpdateChannelTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.UpdateCampaignsFixtures
  alias Edgehog.UpdateCampaigns.UpdateChannel
  require Ash.Query

  describe "deleteUpdateChannel mutation" do
    setup %{tenant: tenant} do
      update_channel = update_channel_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(update_channel)

      {:ok, update_channel: update_channel, id: id}
    end

    test "deletes existing update channel", %{
      tenant: tenant,
      update_channel: update_channel,
      id: id
    } do
      update_channel_data =
        delete_update_channel_mutation(tenant: tenant, id: id)
        |> extract_result!()

      assert update_channel_data["id"] == id
      assert update_channel_data["handle"] == update_channel.handle

      refute UpdateChannel
             |> Ash.Query.filter(id == ^update_channel.id)
             |> Ash.Query.set_tenant(tenant)
             |> Ash.exists?()
    end

    test "fails with non-existing update channel", %{tenant: tenant} do
      id = non_existing_update_channel_id(tenant)

      error = delete_update_channel_mutation(tenant: tenant, id: id) |> extract_error!()

      assert %{
               path: ["deleteUpdateChannel"],
               fields: [:id],
               code: "not_found",
               message: "could not be found"
             } = error
    end
  end

  defp delete_update_channel_mutation(opts) do
    default_document = """
    mutation DeleteUpdateChannel($id: ID!) {
      deleteUpdateChannel(id: $id) {
        result {
          id
          handle
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
             data: %{"deleteUpdateChannel" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteUpdateChannel" => %{
                 "result" => update_channel
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert update_channel != nil

    update_channel
  end

  defp non_existing_update_channel_id(tenant) do
    fixture = update_channel_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture, tenant: tenant)

    id
  end
end
