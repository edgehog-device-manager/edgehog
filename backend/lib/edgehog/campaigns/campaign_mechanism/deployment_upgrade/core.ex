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

defimpl Edgehog.Campaigns.CampaignMechanism.Core,
  for: Edgehog.Campaigns.CampaignMechanism.DeploymentUpgrade do
  @moduledoc """
  Core implementation for Upgrade Operation on deployment campaign execution.

  This module implements the `Edgehog.Campaigns.CampaignMechanism.Core` behavior for deployment campaigns,
  providing the business logic for managing container deployments across target devices.
  """

  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.CampaignMechanism.Core.Any
  alias Edgehog.Campaigns.CampaignMechanism.Helpers
  alias Edgehog.Containers
  alias Edgehog.Containers.Deployment

  require Ash.Query
  require Logger

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
    # TODO: add timeout information on the deployment and correctly handle this case
    deployment = Containers.fetch_deployment!(operation_id, tenant: tenant_id)
    Containers.mark_deployment_as_timed_out!(deployment, tenant: tenant_id)
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
    with {:error, reason} <-
           Phoenix.PubSub.subscribe(Edgehog.PubSub, "deployments:#{operation_id}") do
      raise reason
    end
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
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "deployments:#{operation_id}")
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

  @doc """
  Lists all in-progress targets for a campaign.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.

  ## Returns
    - A list of in-progress campaign targets.
  """
  def list_in_progress_targets(_mechanism, tenant_id, campaign_id) do
    Campaigns.list_in_progress_targets!(campaign_id,
      tenant: tenant_id
    )
  end

  # Operation Execution

  @doc """
  Upgrades the release on the target device to a new target release.

  ## Parameters
    - mechanism: The campaign mechanism struct containing the release and target_release.
    - target: The deployment target struct.

  ## Returns
    - `{:ok, target}` if the upgrade command is successfully sent.
    - `{:ok, :already_in_desired_state}` if the target release is already deployed.
    - `{:error, :deployment_not_found}` if the current deployment doesn't exist on the target.
    - `{:error, :deployment_deleting}` if the deployment is being deleted.
    - `{:error, reason}` for any other errors.
  """
  def do_operation(mechanism, target) do
    upgrade(target, mechanism.release, mechanism.target_release)
  end

  defp upgrade(target, release, target_release) do
    cond do
      Helpers.application_deployed?(target, target_release) ->
        {:ok, :already_in_desired_state}

      Helpers.application_deployed?(target, release) ->
        do_upgrade(target, release, target_release)

      true ->
        {:error, :deployment_not_found}
    end
  end

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

  @doc """
  Retries the target operation based on current deployment state.

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

  defp retry_target_operation(target) do
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

  # Error Handling
  @doc """
  Formats and logs a failure message for an operation.

  Fetches the latest error event and logs the device ID,
  operation type, and error message.

  ## Parameters
    - mechanism: The campaign mechanism containing the type information.
    - operation: The operation struct (Deployment).

  ## Returns
    - `:ok` (this function is called for its side effect of logging).
  """
  def format_operation_failure_log(mechanism, operation) do
    latest_error_message =
      case get_latest_error_for_deployment!(operation.tenant_id, operation.id) do
        %{message: message} -> message
        nil -> "Could not find any error event."
      end

    Logger.notice("Device #{operation.device_id} #{mechanism.type} operation failed: #{latest_error_message}")
  end

  defp get_latest_error_for_deployment!(tenant_id, deployment_id) do
    Deployment.Event
    |> Ash.Query.filter(deployment_id == ^deployment_id)
    |> Ash.Query.filter(type == :error)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read_first!(tenant: tenant_id)
  end

  @doc """
  Renders a more descriptive error message based on the given reason and device id.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - reason: The error reason.
    - device_id: The device ID.

  ## Returns
    - A string describing the error.
  """
  def error_message(mechanism, reason, device_id) do
    # Delegate to Any for generic error messages
    Any.error_message(mechanism, reason, device_id)
  end

  # Delegate common functions to Any implementation
  defdelegate get_campaign!(mechanism, tenant_id, campaign_id),
    to: Any

  defdelegate mark_campaign_in_progress!(mechanism, campaign, now \\ DateTime.utc_now()),
    to: Any

  defdelegate mark_campaign_as_failed!(mechanism, campaign, now \\ DateTime.utc_now()),
    to: Any

  defdelegate mark_campaign_as_successful!(mechanism, campaign, now \\ DateTime.utc_now()),
    to: Any

  defdelegate get_campaign_status(mechanism, campaign),
    to: Any

  defdelegate get_target_count(mechanism, tenant_id, campaign_id),
    to: Any

  defdelegate get_failed_target_count(mechanism, tenant_id, campaign_id),
    to: Any

  defdelegate get_in_progress_target_count(mechanism, tenant_id, campaign_id),
    to: Any

  defdelegate available_slots(mechanism, in_progress_count),
    to: Any

  defdelegate has_idle_targets?(mechanism, tenant_id, campaign_id),
    to: Any

  defdelegate get_target!(mechanism, tenant_id, target_id),
    to: Any

  defdelegate get_target_for_operation!(mechanism, tenant_id, campaign_id, device_id),
    to: Any

  defdelegate mark_target_as_failed!(mechanism, target, now \\ DateTime.utc_now()),
    to: Any

  defdelegate mark_target_as_successful!(mechanism, target, now \\ DateTime.utc_now()),
    to: Any

  defdelegate update_target_latest_attempt(mechanism, target, now \\ DateTime.utc_now()),
    to: Any

  defdelegate pending_request_timeout_ms(mechanism, target, now \\ DateTime.utc_now()),
    to: Any

  defdelegate can_retry?(mechanism, target),
    to: Any

  defdelegate increase_retry_count!(mechanism, target),
    to: Any

  defdelegate temporary_error?(mechanism, reason),
    to: Any
end
