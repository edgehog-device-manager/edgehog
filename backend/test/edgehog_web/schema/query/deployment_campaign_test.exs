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

defmodule EdgehogWeb.Schema.Query.DeploymentCampaignTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DeploymentCampaignsFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  describe "deploymentCampaigns" do
    setup %{tenant: tenant} do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)

      deployment_channel =
        channel_fixture(target_group_ids: [target_group.id], tenant: tenant)

      release = release_fixture(tenant: tenant, system_models: 1)

      device =
        [release_id: release.id, online: true, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      context = %{
        deployment_channel: deployment_channel,
        release: release,
        device: device
      }

      {:ok, context}
    end

    test "return empty deployment campaigns", %{tenant: tenant} do
      assert [] = [tenant: tenant] |> deployment_campaigns() |> extract_result!()
    end

    test "returns available deployment campaigns", %{
      tenant: tenant,
      release: release,
      deployment_channel: deployment_channel
    } do
      deployment_campaign =
        deployment_campaign_fixture(
          release_id: release.id,
          channel_id: deployment_channel.id,
          tenant: tenant
        )

      expected_deployment_campaign_id = AshGraphql.Resource.encode_relay_id(deployment_campaign)
      expected_release_id = AshGraphql.Resource.encode_relay_id(release)

      assert [deployment_campaign_data] =
               [tenant: tenant]
               |> deployment_campaigns()
               |> extract_result!()

      assert deployment_campaign_data["id"] == expected_deployment_campaign_id
      assert deployment_campaign_data["status"] == "IDLE"
      assert deployment_campaign_data["outcome"] == nil
      assert deployment_campaign_data["release"]["version"] == release.version
      assert deployment_campaign_data["release"]["id"] == expected_release_id
      assert deployment_campaign_data["channel"]["name"] == deployment_channel.name
      assert deployment_campaign_data["channel"]["handle"] == deployment_channel.handle
    end
  end

  defp deployment_campaigns(opts) do
    default_document = """
      query {
        deploymentCampaigns {
          edges {
            node {
              id
              name
              release {
                id
                version
                application {
                  id
                  name
                }
              }
              status
              channel {
                id
                name
                handle
              }
              deploymentTargets {
                edges {
                  node {
                    id
                    device {
                      id
                    }
                    deployment {
                      id
                      state
                      resourcesState
                    }
                  }
                }
              }
            }
          }
        }
      }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deploymentCampaigns" => %{"edges" => deployment_campaigns}
             }
           } = result

    refute Map.get(result, :errors)

    assert deployment_campaigns != nil

    remove_nodes(deployment_campaigns)
  end

  defp remove_nodes(campaigns) do
    Enum.map(campaigns, fn %{"node" => campaign} -> campaign end)
  end
end
