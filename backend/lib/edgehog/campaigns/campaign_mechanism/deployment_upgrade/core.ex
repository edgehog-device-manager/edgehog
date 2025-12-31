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
  for: Edgehog.Campaigns.CampaignMechanism.DeploymentUpgrade do
  @moduledoc """
  Core implementation for Upgrade Operation on deployment campaign execution.

  This module implements the `Edgehog.Campaigns.CampaignMechanism.Core` behavior for deployment campaigns,
  providing the business logic for managing container deployments across target devices.
  """

  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.CampaignMechanism.Helpers
  alias Edgehog.Containers

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
  Fetches the next valid target that has the application deployed.

  ## Parameters
    - mechanism: The campaign mechanism struct containing release info.
    - campaign_id: The ID of the campaign.
    - tenant_id: The ID of the tenant.

  ## Returns
    - `{:ok, target}` if a valid target is found.
    - `{:error, reason}` if no valid target is available.
  """
  def fetch_next_valid_target(mechanism, campaign_id, tenant_id) do
    Campaigns.fetch_next_valid_target_with_application_deployed(
      campaign_id,
      mechanism.release.application_id,
      tenant: tenant_id
    )
  end

  # Operation Execution

  @doc """
  Executes the upgrade operation for the target.

  ## Parameters
    - mechanism: The campaign mechanism struct containing the release and target_release.
    - target: The deployment target struct.

  ## Returns
    - `{:ok, target}` if the upgrade command is successfully sent.
    - `{:ok, :already_in_desired_state}` if target release is already deployed.
    - `{:error, reason}` if the operation fails.
  """
  def do_operation(mechanism, target) do
    upgrade(target, mechanism.release, mechanism.target_release)
  end

  @doc """
  Retries the upgrade operation for a target.

  Determines the appropriate retry action based on the current deployment state:
  - If stopped: retries starting the deployment
  - Otherwise: retries sending the deployment

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - target: The deployment target struct.

  ## Returns
    - `:ok` if the retry is successful.
    - `{:error, reason}` if the retry fails.
  """
  def retry_operation(_mechanism, target) do
    retry_target_operation(target)
  end

  # Mechanism Configuration

  @doc """
  Loads and returns the full mechanism configuration from a campaign.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - campaign: The campaign struct to load the mechanism from.

  ## Returns
    - The fully loaded deployment upgrade mechanism with release and target_release data.
  """
  def get_mechanism(_mechanism, campaign) do
    mechanism =
      campaign
      |> Ash.load!(
        campaign_mechanism: [
          deployment_upgrade: [
            release: [containers: [:networks, :volumes, :image]],
            target_release: []
          ]
        ]
      )
      |> Map.get(:campaign_mechanism)

    mechanism.value
  end

  # Upgrade Operation

  @doc """
  Upgrades the release on the target device to a new target release.

  ## Parameters
    - target: The deployment target struct.
    - release: The current release struct to be upgraded from.
    - target_release: The target release struct to upgrade to.

  ## Returns
    - `{:ok, target}` if the upgrade command is successfully sent.
    - `{:ok, :already_in_desired_state}` if the target release is already deployed.
    - `{:error, :deployment_not_found}` if the current deployment doesn't exist on the target.
    - `{:error, :deployment_deleting}` if the deployment is being deleted.
    - `{:error, reason}` for any other errors.
  """
  def upgrade(target, release, target_release) do
    cond do
      Helpers.application_deployed?(target, target_release) ->
        {:ok, :already_in_desired_state}

      Helpers.application_deployed?(target, release) ->
        do_upgrade(target, release, target_release)

      true ->
        {:error, :deployment_not_found}
    end
  end

  # Retry Operations

  @doc """
  Retries the target operation based on current deployment state.

  ## Parameters
    - target: The deployment target struct.

  ## Returns
    - `:ok` if the retry is successful.
    - `{:error, reason}` if the retry fails.
  """
  def retry_target_operation(target) do
    deployment = Ash.load!(target, :deployment, tenant: target.tenant_id).deployment

    case deployment.state do
      :stopped ->
        # Deployment is already deployed but not started; retry starting
        Helpers.do_retry_target_operation(target, :start)

      _ ->
        # Deployment not yet deployed or in an unexpected state; retry deployment
        Helpers.do_retry_target_operation(target, :send_deployment)
    end
  end

  # Private Helpers

  defp do_upgrade(target, release, target_release) do
    target = Campaigns.update_target_latest_attempt!(target, DateTime.utc_now())

    device =
      target
      |> Ash.load!(:device)
      |> Map.get(:device)

    {:ok, current_deployment} =
      Containers.deployment_by_identity(device.id, release.id, tenant: target.tenant_id)

    if current_deployment.state == :deleting do
      {:error, :deployment_deleting}
    else
      upgrade_result =
        current_deployment
        |> Ash.Changeset.for_update(:upgrade_release, %{target: target_release.id}, tenant: target.tenant_id)
        |> Ash.update()

      case upgrade_result do
        {:ok, new_deployment} ->
          Campaigns.set_target_deployment(target, new_deployment.id, tenant: target.tenant_id)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
