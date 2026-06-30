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

defmodule EdgehogWeb.Schema.Mutation.DeleteCampaignTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.CampaignsFixtures

  alias Edgehog.Campaigns

  describe "delete campaign mutation" do
    setup %{tenant: tenant} do
      campaign =
        [tenant: tenant]
        |> campaign_fixture()
        |> Campaigns.mark_campaign_scheduled!(tenant: tenant)

      {:ok, campaign: campaign}
    end

    test "deletes a campaign", %{campaign: campaign, tenant: tenant} do
      id = AshGraphql.Resource.encode_relay_id(campaign)

      result =
        [id: id, tenant: tenant]
        |> delete_campaign_mutation()
        |> extract_result!()

      assert result["id"] == id
    end

    test "fails with non-existing campaign", %{tenant: tenant} do
      non_existent_campaign_id = non_existing_campaign_id(tenant)

      result = delete_campaign_mutation(id: non_existent_campaign_id, tenant: tenant)

      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end

    test "returns an error when trying to update a campaign that has already started", %{
      campaign: campaign,
      tenant: tenant
    } do
      id = AshGraphql.Resource.encode_relay_id(campaign)

      Campaigns.mark_campaign_in_progress!(campaign, tenant: tenant)

      result = delete_campaign_mutation(id: id, tenant: tenant)

      assert %{fields: [:status], message: "Only scheduled campaigns can be deleted"} =
               extract_error!(result)
    end
  end

  defp delete_campaign_mutation(opts) do
    default_document = """
      mutation DeleteCampaign($id: ID!) {
        deleteCampaign(id: $id) {
          result {
            id
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
             data: %{"deleteCampaign" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteCampaign" => %{
                 "result" => campaign
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert campaign

    campaign
  end

  defp non_existing_campaign_id(tenant) do
    fixture = campaign_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture, action: :destroy_fixture)

    id
  end
end
