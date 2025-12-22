#
# This file is part of Edgehog.
#
# Copyright 2023 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.DeleteChannelTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.CampaignsFixtures

  alias Edgehog.Campaigns.Channel

  require Ash.Query

  describe "deleteChannel mutation" do
    setup %{tenant: tenant} do
      channel = channel_fixture(tenant: tenant)
      id = AshGraphql.Resource.encode_relay_id(channel)

      {:ok, channel: channel, id: id}
    end

    test "deletes existing channel", %{
      tenant: tenant,
      channel: channel,
      id: id
    } do
      channel_data =
        [tenant: tenant, id: id]
        |> delete_channel_mutation()
        |> extract_result!()

      assert channel_data["id"] == id
      assert channel_data["handle"] == channel.handle

      refute Channel
             |> Ash.Query.filter(id == ^channel.id)
             |> Ash.Query.set_tenant(tenant)
             |> Ash.exists?()
    end

    test "fails with non-existing channel", %{tenant: tenant} do
      id = non_existing_channel_id(tenant)

      error = [tenant: tenant, id: id] |> delete_channel_mutation() |> extract_error!()

      assert %{
               path: ["deleteChannel"],
               fields: [:id],
               code: "not_found",
               message: "could not be found"
             } = error
    end

    test "fails if the channel is used in an Update Campaign", %{
      tenant: tenant,
      channel: channel,
      id: id
    } do
      campaign_fixture(
        tenant: tenant,
        mechanism_type: :firmware_upgrade,
        channel_id: channel.id
      )

      result = delete_channel_mutation(tenant: tenant, id: id)

      assert %{fields: [:id], message: "would leave records behind"} = extract_error!(result)
    end
  end

  defp delete_channel_mutation(opts) do
    default_document = """
    mutation DeleteChannel($id: ID!) {
      deleteChannel(id: $id) {
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
             data: %{"deleteChannel" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteChannel" => %{
                 "result" => channel
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert channel

    channel
  end

  defp non_existing_channel_id(tenant) do
    fixture = channel_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture, tenant: tenant)

    id
  end
end
