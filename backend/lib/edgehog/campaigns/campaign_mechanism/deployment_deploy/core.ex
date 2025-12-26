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

defimpl Edgehog.Campaigns.CampaignMechanism.Core,
  for: Edgehog.Campaigns.CampaignMechanism.DeploymentDeploy do
  @moduledoc """
  Core implementation for Deploy Operation on deployment campaign execution.

  This module implements the `Edgehog.Campaigns.CampaignMechanism.Core` behavior for deployment campaigns,
  providing the business logic for managing container deployments across target devices.
  """

  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.CampaignMechanism.Helpers

  require Ash.Query

  # Operation Tracking

  @doc """
  Returns the deployment ID as the operation identifier for tracking.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - target: The deployment target struct.

  ## Returns
    - The deployment ID from the target.
  """
  def get_operation_id(_mechanism, target), do: target.deployment_id

  @doc """
  Marks a deployment operation as timed out.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - operation_id: The ID of the deployment operation.
    - tenant_id: The ID of the tenant.

  ## Returns
    - The updated deployment struct marked as timed out.
  """
  def mark_operation_as_timed_out!(_mechanism, operation_id, tenant_id) do
    Helpers.mark_deployment_as_timed_out!(operation_id, tenant_id)
  end

  @doc """
  Subscribes to deployment operation updates via PubSub.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - operation_id: The ID of the deployment operation.

  ## Returns
    - `:ok` on success.
    - Raises an error on failure.
  """
  def subscribe_to_operation_updates!(_mechanism, operation_id) do
    Helpers.subscribe_to_deployment_updates!(operation_id)
  end

  @doc """
  Unsubscribes from deployment operation updates via PubSub.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - operation_id: The ID of the deployment operation.

  ## Returns
    - `:ok`
  """
  def unsubscribe_to_operation_updates!(_mechanism, operation_id) do
    Helpers.unsubscribe_from_deployment_updates!(operation_id)
  end

  # Target Management

  @doc """
  Fetches the next valid target for deployment.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - campaign_id: The ID of the campaign.
    - tenant_id: The ID of the tenant.

  ## Returns
    - `{:ok, target}` if a valid target is found.
    - `{:error, reason}` if no valid target is available.
  """
  def fetch_next_valid_target(_mechanism, campaign_id, tenant_id) do
    Campaigns.fetch_next_valid_target(campaign_id, tenant: tenant_id)
  end

  # Operation Execution

  @doc """
  Executes the deploy operation for the target.

  ## Parameters
    - mechanism: The campaign mechanism struct containing the release.
    - target: The deployment target struct.

  ## Returns
    - `{:ok, target}` if the deployment is successful.
    - `{:ok, :already_in_desired_state}` if already deployed.
    - `{:error, reason}` if the operation fails.
  """
  def do_operation(mechanism, target) do
    deploy(target, mechanism.release)
  end

  @doc """
  Retries the deploy operation for a target.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - target: The deployment target struct.

  ## Returns
    - `:ok` if the retry is successful.
    - `{:error, reason}` if the retry fails.
  """
  def retry_operation(_mechanism, target) do
    Helpers.do_retry_target_operation(target, :send_deployment)
  end

  # Mechanism Configuration

  @doc """
  Loads and returns the full mechanism configuration from a campaign.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - campaign: The campaign struct to load the mechanism from.

  ## Returns
    - The fully loaded deployment deploy mechanism with release data.
  """
  def get_mechanism(_mechanism, campaign) do
    mechanism =
      campaign
      |> Ash.load!(
        campaign_mechanism: [
          deployment_deploy: [release: [containers: [:networks, :volumes, :image]]]
        ]
      )
      |> Map.get(:campaign_mechanism)

    mechanism.value
  end

  # Deploy Operation

  @doc """
  Deploys the release to the target using the specified deployment mechanism.

  ## Parameters
    - target: The deployment target struct.
    - release: The release struct to be deployed.

  ## Returns
    - `{:ok, :already_in_desired_state}` if the release is already deployed to the target.
    - `{:ok, target}` if the deployment operation is successful.
    - `{:error, reason}` if the deployment operation fails.
  """
  def deploy(target, release) do
    # TODO: this crashes if called multiple times. The first time creates all
    # the necessary resources, the next time, if not completely deployed, retries
    # to send all the information but fails as the resources are already present.
    if Helpers.application_deployed?(target, release) do
      {:ok, :already_in_desired_state}
    else
      {:ok, target} = do_deploy(target, release)

      deployment_result =
        target
        |> Ash.load!(:deployment, tenant: target.tenant_id)
        |> Map.get(:deployment)
        |> Ash.Changeset.for_update(:send_deployment, %{}, tenant: target.tenant_id)
        |> Ash.update()

      with {:ok, _deployment} <- deployment_result do
        {:ok, target}
      end
    end
  end

  # Private Helpers

  defp do_deploy(target, release) do
    target
    |> Campaigns.update_target_latest_attempt!(DateTime.utc_now())
    |> Campaigns.link_deployment(release)
  end
end
