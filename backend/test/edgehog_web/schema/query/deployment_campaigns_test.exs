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

defmodule EdgehogWeb.Schema.Query.DeploymentCampaignsTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  describe "deploymentCampaigns" do
    setup %{tenant: tenant} do
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)
      release = release_fixture(tenant: tenant, system_models: 1)

      device =
        [release_id: release.id, online: true, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      context = %{
        channel: channel,
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
      channel: channel
    } do
      deployment_deploy_campaign =
        campaign_fixture(
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      deployment_start_campaign =
        campaign_fixture(
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant,
          mechanism_type: :deployment_start,
          deploy_for_required_operations: true
        )

      expected_deployment_deploy_campaign_id =
        AshGraphql.Resource.encode_relay_id(deployment_deploy_campaign)

      expected_deployment_start_campaign_id =
        AshGraphql.Resource.encode_relay_id(deployment_start_campaign)

      expected_release_id = AshGraphql.Resource.encode_relay_id(release)

      assert deployment_campaign_data =
               [tenant: tenant]
               |> deployment_campaigns()
               |> extract_result!()

      [response_deployment_deploy_campaign] =
        Enum.filter(deployment_campaign_data, fn campaign ->
          campaign["campaignMechanism"]["__typename"] == "DeploymentDeploy"
        end)

      [response_deployment_start_campaign] =
        Enum.filter(deployment_campaign_data, fn campaign ->
          campaign["campaignMechanism"]["__typename"] == "DeploymentStart"
        end)

      assert Enum.count(deployment_campaign_data) == 2

      assert response_deployment_deploy_campaign["id"] == expected_deployment_deploy_campaign_id
      assert response_deployment_deploy_campaign["status"] == "IDLE"
      assert response_deployment_deploy_campaign["outcome"] == nil

      assert response_deployment_deploy_campaign["campaignMechanism"]["release"]["version"] ==
               release.version

      assert response_deployment_deploy_campaign["campaignMechanism"]["release"]["id"] ==
               expected_release_id

      assert response_deployment_deploy_campaign["channel"]["name"] == channel.name
      assert response_deployment_deploy_campaign["channel"]["handle"] == channel.handle

      assert response_deployment_start_campaign["id"] == expected_deployment_start_campaign_id
      assert response_deployment_start_campaign["status"] == "IDLE"
      assert response_deployment_start_campaign["outcome"] == nil

      assert response_deployment_start_campaign["campaignMechanism"]["release"]["version"] ==
               release.version

      assert response_deployment_start_campaign["campaignMechanism"]["release"]["id"] ==
               expected_release_id

      assert response_deployment_start_campaign["channel"]["name"] == channel.name
      assert response_deployment_start_campaign["channel"]["handle"] == channel.handle
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
              status
              campaignMechanism {
              __typename
                ... on DeploymentDeploy {
                  maxFailurePercentage
                  maxInProgressOperations
                  requestRetries
                  requestTimeoutSeconds
                  release {
                    id
                    version
                    application {
                      id
                      name
                    }
                  }
                }

                ... on DeploymentStop {
                  maxFailurePercentage
                  maxInProgressOperations
                  requestRetries
                  requestTimeoutSeconds
                  release {
                    id
                    version
                    application {
                      id
                      name
                    }
                  }
                }

                ... on DeploymentStart {
                  maxFailurePercentage
                  maxInProgressOperations
                  requestRetries
                  requestTimeoutSeconds
                  release {
                    id
                    version
                    application {
                      id
                      name
                    }
                  }
                }

                ... on DeploymentDelete {
                  maxFailurePercentage
                  maxInProgressOperations
                  requestRetries
                  requestTimeoutSeconds
                  release {
                    id
                    version
                    application {
                      id
                      name
                    }
                  }
                }

                ... on DeploymentUpgrade {
                  maxFailurePercentage
                  maxInProgressOperations
                  requestRetries
                  requestTimeoutSeconds
                  release {
                    id
                    version
                    application {
                      id
                      name
                    }
                  }
                  targetRelease {
                    id
                    version
                    application {
                      id
                      name
                    }
                  }
                }
              }
              channel {
                id
                name
                handle
              }
              campaignTargets {
                edges {
                  node {
                    id
                    device {
                      id
                    }
                    deployment {
                      id
                      state
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

    assert deployment_campaigns

    remove_nodes(deployment_campaigns)
  end

  defp remove_nodes(campaigns) do
    Enum.map(campaigns, fn %{"node" => campaign} -> campaign end)
  end
end
