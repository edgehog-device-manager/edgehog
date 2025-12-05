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

defmodule Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Core do
  @moduledoc """
  Core implementation for lazy deployment campaign execution.

  This module implements the `Edgehog.Campaigns.Executors.Core` behavior for deployment campaigns,
  providing the business logic for managing container deployments across target devices.

  ## Terminology

  - **Operation**: In the context of deployment campaigns, the "operation" refers to a `Deployment`
    resource that represents a container deployment on a device.
  - **Target**: A `DeploymentTarget` represents a device that is part of the campaign.
  - **Mechanism**: The deployment mechanism (lazy batch) that controls rollout behavior.

  ## Operation Types

  The module supports multiple operation types for container management:
  - `:deploy` - Deploy a new release to a device
  - `:upgrade` - Upgrade an existing deployment to a new release version
  - `:start` - Start a stopped deployment
  - `:stop` - Stop a running deployment
  - `:delete` - Remove a deployment
  """
  use Edgehog.Campaigns.Executors.Core

  alias Edgehog.Campaigns.Executors.Core
  alias Edgehog.Containers
  alias Edgehog.Containers.Deployment
  alias Edgehog.DeploymentCampaigns
  alias Edgehog.DeploymentCampaigns.DeploymentCampaign
  alias Edgehog.DeploymentCampaigns.DeploymentTarget
  alias Edgehog.Error.AstarteAPIError

  require Ash.Query
  require Logger

  # Campaign Management

  @doc """
  Fetch the `DeploymentCampaign` for `campaign_id` in the given tenant.

  Raises if the campaign cannot be found. This helper centralizes the load
  options used throughout the module.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the deployment campaign.

  ## Returns
    - The deployment campaign struct with preloaded associations.
  """
  @impl Core
  def get_campaign!(tenant_id, campaign_id) do
    campaign_id
    |> DeploymentCampaigns.fetch_campaign!(tenant: tenant_id)
    |> Ash.load!(
      [target_release: [], release: [containers: [:networks, :volumes, :image]]],
      tenant: tenant_id
    )
    |> Ash.load!(:total_target_count)
  end

  @doc """
  Marks a deployment campaign as in progress.

  ## Parameters
    - campaign: The deployment campaign struct.

  ## Returns
    - The updated deployment campaign struct marked as in progress.
  """
  @impl Core
  def mark_campaign_in_progress!(campaign) do
    DeploymentCampaigns.mark_campaign_in_progress!(campaign)
  end

  @doc """
  Marks a deployment campaign as failed.

  ## Parameters
    - campaign: The deployment campaign struct.

  ## Returns
    - The updated deployment campaign struct marked as failed.
  """
  @impl Core
  def mark_campaign_as_failed!(campaign) do
    DeploymentCampaigns.mark_campaign_failed!(campaign)
  end

  @doc """
  Marks a deployment campaign as successful.

  ## Parameters
    - campaign: The deployment campaign struct.

  ## Returns
    - The updated deployment campaign struct marked as successful.
  """
  @impl Core
  def mark_campaign_as_successful!(campaign) do
    DeploymentCampaigns.mark_campaign_successful!(campaign)
  end

  # Campaign Data & Configuration

  @doc """
  Return the deployment mechanism configuration stored on the campaign.
  """
  @impl Core
  def get_mechanism(campaign), do: campaign.deployment_mechanism.value

  @doc """
  Return the persisted campaign status.

  Expected values are `:idle`, `:in_progress` or `:finished`.
  """
  @impl Core
  def get_campaign_status(campaign), do: campaign.status

  @doc """
  Load the small payload of campaign-specific data that the executor needs
  while running. For deployment campaigns we include:

  - `:release` - the current release being deployed
  - `:target_release` - the target release for upgrades
  - `:operation_type` - one of `:deploy | :upgrade | :start | :stop | :delete`
  """
  @impl Core
  def load_campaign_data(_tenant_id, campaign) do
    %{
      release: campaign.release,
      target_release: campaign.target_release,
      operation_type: campaign.operation_type
    }
  end

  @doc """
  Fetches a deployment campaign by its ID and tenant ID, raising an error if not found.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the deployment campaign.

  ## Returns
    - The deployment campaign struct.
  """
  def get_deployment_campaign!(tenant_id, campaign_id) do
    DeploymentCampaigns.fetch_campaign!(campaign_id, tenant: tenant_id, load: [:release])
  end

  # Campaign Metrics

  @doc """
  Fetches the total target count for a given deployment campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the deployment campaign.

  ## Returns
    - The total number of deployment targets associated with the campaign.
  """
  @impl Core
  def get_target_count(tenant_id, campaign_id) do
    campaign = get_deployment_campaign!(tenant_id, campaign_id)

    campaign
    |> Ash.load!(:total_target_count, tenant: tenant_id)
    |> Map.get(:total_target_count)
  end

  @doc """
  Fetches the failed target count for a given deployment campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the deployment campaign.

  ## Returns
    - The number of failed deployment targets associated with the campaign.
  """
  @impl Core
  def get_failed_target_count(tenant_id, campaign_id) do
    tenant_id
    |> get_deployment_campaign!(campaign_id)
    |> Ash.load!(:failed_target_count)
    |> Map.get(:failed_target_count)
  end

  @doc """
  Fetches the in progress target count for a given deployment campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the deployment campaign.

  ## Returns
    - The number of in progress deployment targets associated with the campaign.
  """
  @impl Core
  def get_in_progress_target_count(tenant_id, campaign_id) do
    tenant_id
    |> get_deployment_campaign!(campaign_id)
    |> Ash.load!(:in_progress_target_count, tenant: tenant_id)
    |> Map.get(:in_progress_target_count)
  end

  @doc """
  Fetches the available slots for a given deployment campaign.

  ## Parameters
    - mechanism: The deployment mechanism configuration.
    - in_progress_count: The count of in progress targets.

  ## Returns
    - The number of available slots for deployment targets.
  """
  @impl Core
  def available_slots(mechanism, in_progress_count) do
    max(0, mechanism.max_in_progress_deployments - in_progress_count)
  end

  @doc """
  Checks whether a deployment campaign has idle targets.

  ## Parameters
    - tenant_id: The ID of the Tenant.
    - deployment_campaign_id: The deployment campaign to check.

  ## Returns
    - `true` if there are idle targets, `false` otherwise.
  """
  @impl Core
  def has_idle_targets?(tenant_id, deployment_campaign_id) do
    deployment_campaign =
      Ash.get!(DeploymentCampaign, deployment_campaign_id,
        tenant: tenant_id,
        load: [:idle_target_count]
      )

    deployment_campaign.idle_target_count > 0
  end

  @doc """
  Returns true if the failure threshold for the rollout has been exceeded.

  ## Parameters
    - target_count: The total number of targets in the campaign.
    - failed_count: The number of failed targets.
    - rollout: The rollout configuration containing `max_failure_percentage`.

  ## Returns
    - `true` if the failure percentage exceeds the threshold.
    - `false` otherwise.
  """
  @impl Core
  def failure_threshold_exceeded?(target_count, failed_count, rollout) do
    failed_count / target_count * 100 > rollout.max_failure_percentage
  end

  # Target Management

  @doc """
  Fetch a `DeploymentTarget` by id for the given tenant.

  Delegates to the `DeploymentCampaigns` data layer and will raise if the
  target is not found.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - target_id: The ID of the deployment target.

  ## Returns
    - The deployment target struct.
  """
  @impl Core
  def get_target!(tenant_id, target_id) do
    DeploymentCampaigns.fetch_target!(target_id, tenant: tenant_id)
  end

  @doc """
  Fetches the deployment target associated with a given device ID and campaign ID.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the deployment campaign.
    - device_id: The ID of the device.

  ## Returns
    - The deployment target struct associated with the device ID and campaign ID.
  """
  @impl Core
  def get_target_for_operation!(tenant_id, campaign_id, device_id) do
    DeploymentCampaigns.fetch_target_by_device_and_campaign!(
      device_id,
      campaign_id,
      tenant: tenant_id
    )
  end

  @doc """
  Fetches the list of targets for the campaign with `in_progress` state.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - deployment_campaign_id: The deployment campaign to check.

  ## Returns
    - A list of targets with `in_progress` status.
  """
  @impl Core
  def list_in_progress_targets(tenant_id, deployment_campaign_id) do
    DeploymentCampaigns.list_in_progress_targets!(deployment_campaign_id,
      tenant: tenant_id
    )
  end

  @doc """
  Fetches the next valid deployment target for a given deployment campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - deployment_campaign_id: The ID of the deployment campaign.
    - campaign_data: Campaign-specific data including operation type and release information.

  ## Returns
    - The next valid target for the campaign, or `nil` if none available.
  """
  @impl Core
  def fetch_next_valid_target(tenant_id, deployment_campaign_id, campaign_data) do
    if campaign_data.operation_type == :deploy do
      DeploymentCampaigns.fetch_next_valid_target(deployment_campaign_id, tenant: tenant_id)
    else
      DeploymentCampaigns.fetch_next_valid_target_with_application_deployed(
        deployment_campaign_id,
        campaign_data.release.application_id,
        tenant: tenant_id
      )
    end
  end

  @doc """
  Fetches the next valid deployment target for a given deployment campaign
  that has the specified application already deployed.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - deployment_campaign_id: The ID of the deployment campaign.
    - application_id: The ID of the application the operation is targeting.

  ## Returns
    - The next valid target for the campaign, or `nil` if none available.
  """
  def fetch_next_valid_target_with_application_deployed(tenant_id, deployment_campaign_id, application_id) do
    DeploymentCampaigns.fetch_next_valid_target_with_application_deployed(
      deployment_campaign_id,
      application_id,
      tenant: tenant_id
    )
  end

  @doc delegate_to: {DeploymentCampaigns, :mark_target_as_failed!, 2}
  @impl Core
  def mark_target_as_failed!(target, now \\ DateTime.utc_now()) do
    DeploymentCampaigns.mark_target_as_failed!(target, %{completion_timestamp: now})
  end

  @doc delegate_to: {DeploymentCampaigns, :mark_target_as_successful!, 2}
  @impl Core
  def mark_target_as_successful!(target, now \\ DateTime.utc_now()) do
    DeploymentCampaigns.mark_target_as_successful!(target, %{completion_timestamp: now})
  end

  @doc delegate_to: {DeploymentCampaigns, :update_target_latest_attempt!, 2}
  @impl Core
  def update_target_latest_attempt!(target, now \\ DateTime.utc_now()) do
    DeploymentCampaigns.update_target_latest_attempt!(target, now)
  end

  # Operation Execution

  @doc """
  Return the identifier of the underlying operation for a target.

  For deployment campaigns the operation is a `Deployment` and this returns
  the `deployment_id` that the executor listens to for updates.
  """
  @impl Core
  def get_operation_id(target), do: target.deployment_id

  @doc """
  Executes an operation on a target device based on campaign data.

  ## Parameters
    - target: The target device where the operation will be performed.
    - campaign_data: Campaign-specific data including release and operation type.
    - mechanism: The deployment mechanism configuration (unused in current implementation).

  ## Returns
    - `{:ok, result}` when the operation succeeds.
    - `{:ok, :already_in_desired_state}` if the target is already in the desired state.
    - `{:error, reason}` when the operation fails.
  """
  @impl Core
  def do_operation(target, campaign_data, _mechanism) do
    do_operation(
      target,
      campaign_data.release,
      campaign_data.target_release,
      campaign_data.operation_type
    )
  end

  @doc """
  Executes the specified operation on a target device using the lazy deployment mechanism.

  ## Parameters
    - target: The target device where the operation will be performed.
    - release: The release/software package to be deployed or operated on.
    - target_release: The target release for upgrade operations (may be `nil` for non-upgrade operations).
    - operation_type: The type of operation to perform (`:deploy`, `:upgrade`, `:start`, `:stop`, `:delete`).

  ## Returns
    - `{:ok, result}` when the operation succeeds.
    - `{:ok, :already_in_desired_state}` if the target is already in the desired state.
    - `{:error, :not_implemented}` for operations that are not yet implemented.
    - `{:error, reason}` when the operation fails.
  """
  def do_operation(target, release, target_release, operation_type) do
    case operation_type do
      :deploy ->
        deploy(target, release)

      :upgrade ->
        upgrade(target, release, target_release)

      :start ->
        start(target, release)

      :stop ->
        stop(target, release)

      :delete ->
        delete(target, release)

      _ ->
        deploy(target, release)
    end
  end

  # Deployment Operations

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
    # the necessary resources, the next time, if not completely deployed, reties
    # to send all the information but fails as the resources are already
    # present.
    if application_deployed?(target, release) do
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

  defp do_deploy(target, release) do
    target = update_target_latest_attempt!(target)

    DeploymentCampaigns.deploy_to_target(target, release)
  end

  @doc """
  Starts the release on the target device.

  ## Parameters
    - target: The deployment target struct.
    - release: The release struct to be started.

  ## Returns
    - `{:ok, target}` if the start command is successfully sent.
    - `{:ok, :already_in_desired_state}` if the deployment is already in a started state.
    - `{:error, :deployment_not_found}` if the deployment doesn't exist on the target.
    - `{:error, :deployment_deleting}` if the deployment is being deleted.
    - `{:error, :deployment_transitioning}` if the deployment is in a transitional state.
    - `{:error, reason}` for any other errors.
  """
  def start(target, release) do
    if application_deployed?(target, release) do
      {:ok, updated_target} = link_target_deployment(target, release)

      deployment =
        updated_target
        |> Ash.load!([:deployment], tenant: updated_target.tenant_id)
        |> Map.get(:deployment)

      cond do
        # Check if already started
        deployment.state == :started ->
          {:ok, :already_in_desired_state}

        # Check if being deleted
        deployment.state == :deleting ->
          {:error, :deployment_deleting}

        # Check if in a transitional state
        deployment.state in [:starting, :stopping] ->
          {:error, :deployment_transitioning}

        # Start the deployment
        true ->
          deployment_result =
            deployment
            |> Ash.Changeset.for_update(:start, %{}, tenant: updated_target.tenant_id)
            |> Ash.update()

          with {:ok, _deployment} <- deployment_result do
            {:ok, updated_target}
          end
      end
    else
      {:error, :deployment_not_found}
    end
  end

  @doc """
  Stops the release on the target device.

  ## Parameters
    - target: The deployment target struct.
    - release: The release struct to be stopped.

  ## Returns
    - `{:ok, target}` if the stop command is successfully sent.
    - `{:ok, :already_in_desired_state}` if the deployment is already in a stopped state.
    - `{:error, :deployment_not_found}` if the deployment doesn't exist on the target.
    - `{:error, :deployment_deleting}` if the deployment is being deleted.
    - `{:error, :deployment_transitioning}` if the deployment is in a transitional state.
    - `{:error, reason}` for any other errors.
  """
  def stop(target, release) do
    if application_deployed?(target, release) do
      {:ok, updated_target} = link_target_deployment(target, release)

      deployment =
        updated_target
        |> Ash.load!([:deployment], tenant: updated_target.tenant_id)
        |> Map.get(:deployment)

      cond do
        # Check if already stopped
        deployment.state == :stopped ->
          {:ok, :already_in_desired_state}

        # Check if being deleted
        deployment.state == :deleting ->
          {:error, :deployment_deleting}

        # Check if in a transitional state
        deployment.state in [:starting, :stopping] ->
          {:error, :deployment_transitioning}

        # Stop the deployment
        true ->
          deployment_result =
            deployment
            |> Ash.Changeset.for_update(:stop, %{}, tenant: updated_target.tenant_id)
            |> Ash.update()

          with {:ok, _deployment} <- deployment_result do
            {:ok, updated_target}
          end
      end
    else
      {:error, :deployment_not_found}
    end
  end

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
    - `{:error, :deployment_transitioning}` if the deployment is in a transitional state.
    - `{:error, reason}` for any other errors.
  """
  def upgrade(target, release, target_release) do
    cond do
      application_deployed?(target, target_release) ->
        {:ok, :already_in_desired_state}

      application_deployed?(target, release) ->
        do_upgrade(target, release, target_release)

      true ->
        {:error, :deployment_not_found}
    end
  end

  defp do_upgrade(target, release, target_release) do
    target = update_target_latest_attempt!(target)

    device =
      target
      |> Ash.load!(:device)
      |> Map.get(:device)

    {:ok, current_deployment} =
      Containers.deployment_by_identity(device.id, release.id, tenant: target.tenant_id)

    cond do
      current_deployment.state == :deleting ->
        {:error, :deployment_deleting}

      current_deployment.state in [:starting, :stopping] ->
        {:error, :deployment_transitioning}

      true ->
        upgrade_result =
          current_deployment
          |> Ash.Changeset.for_update(:upgrade_release, %{target: target_release.id}, tenant: target.tenant_id)
          |> Ash.update()

        case upgrade_result do
          {:ok, new_deployment} ->
            DeploymentCampaigns.set_target_deployment(target, new_deployment.id, tenant: target.tenant_id)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Deletes the deployment of the release to the target

  ## Parameters
    - target: The deployment target struct.
    - release: The release struct referenced in the deployment to be deployed.

  ## Returns
    - `{:ok, target}` if the delete command is successfully sent.
    - `{:error, :deployment_transitioning}` if the deployment is in a transitional state.
    - `{:error, :deployment_not_found}`, if the deployment doesn't exist n the target.
    - `{:error, reason}` for any other errors.
  """
  def delete(target, release) do
    if application_deployed?(target, release) do
      {:ok, updated_target} = link_target_deployment(target, release)

      deployment =
        updated_target
        |> Ash.load!([:deployment], tenant: updated_target.tenant_id)
        |> Map.get(:deployment)

      if deployment.state in [:starting, :stopping] do
        {:error, :deployment_transitioning}
      else
        # Delete the deployment
        deployment_result =
          deployment
          |> Ash.Changeset.for_update(:delete, %{}, tenant: updated_target.tenant_id)
          |> Ash.update()

        with {:ok, _deployment} <- deployment_result do
          {:ok, updated_target}
        end
      end
    else
      {:error, :deployment_not_found}
    end
  end

  defp application_deployed?(target, release) do
    device =
      target
      |> Ash.load!(:device)
      |> Map.get(:device)

    case Containers.deployment_by_identity(device.id, release.id, tenant: target.tenant_id) do
      {:ok, _deployment} ->
        true

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} ->
        false

      {:error, other_reason} ->
        raise other_reason
    end
  end

  defp link_target_deployment(target, release) do
    target = update_target_latest_attempt!(target)

    device =
      target
      |> Ash.load!(:device)
      |> Map.get(:device)

    {:ok, deployment} =
      Containers.deployment_by_identity(device.id, release.id, tenant: target.tenant_id)

    DeploymentCampaigns.set_target_deployment(target, deployment.id, tenant: target.tenant_id)
  end

  # Operation Subscription & Timeout

  @doc """
  Subscribes to updates for a specific deployment.

  ## Parameters
    - operation_id: The ID of the deployment to subscribe to.

  ## Returns
    - :ok if the subscription is successful, otherwise raises an error.
  """
  @impl Core
  def subscribe_to_operation_updates!(operation_id) do
    with {:error, reason} <-
           Phoenix.PubSub.subscribe(Edgehog.PubSub, "deployments:#{operation_id}") do
      raise reason
    end
  end

  @doc """
  Unsubscribes from updates for a specific deployment.

  ## Parameters
    - operation_id: The ID of the deployment to unsubscribe from.

  ## Returns
    - `:ok` when the un-subscription is successful.
  """
  @impl Core
  def unsubscribe_to_operation_updates!(operation_id) do
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "deployments:#{operation_id}")
  end

  @doc """
  Marks a deployment operation as timed out.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - operation_id: The ID of the deployment operation.

  ## Returns
    - The updated deployment struct marked as timed out.
  """
  @impl Core
  def mark_operation_as_timed_out!(tenant_id, operation_id) do
    # TODO: add timeout information on the deployment and correctly handle this case
    deployment = Containers.fetch_deployment!(operation_id, tenant: tenant_id)
    Containers.mark_deployment_as_timed_out!(deployment, tenant: tenant_id)
  end

  @doc """
  Return the number of milliseconds to wait before considering the pending
  request to the target as timed out.

  ## Parameters
    - target: The deployment target struct.
    - mechanism: The deployment mechanism configuration.
    - now: The current timestamp (defaults to `DateTime.utc_now()`).

  ## Returns
    - The number of milliseconds remaining before timeout (or `0` if already timed out).
  """
  @impl Core
  def pending_request_timeout_ms(target, mechanism, now \\ DateTime.utc_now()) do
    %DeploymentTarget{latest_attempt: %DateTime{} = latest_attempt} = target

    absolute_timeout_ms = to_timeout(second: mechanism.request_timeout_seconds)
    elapsed_from_latest_request_ms = DateTime.diff(now, latest_attempt, :millisecond)

    max(0, absolute_timeout_ms - elapsed_from_latest_request_ms)
  end

  # Retry Logic

  @doc """
  Tests whether the target can be retried based on the mechanism settings.

  ## Parameters
    - target: the considered target.
    - mechanism: the mechanism settings.

  ## Returns
    - `true`: if the target has less retries then the number allowed by the
      mechanism settings.
    - `false`: otherwise.
  """
  @impl Core
  def can_retry?(target, mechanism) do
    target.retry_count < mechanism.create_request_retries
  end

  @doc delegate_to: {DeploymentCampaigns, :increase_target_retry_count!, 1}
  @impl Core
  def increase_retry_count!(target) do
    DeploymentCampaigns.increase_target_retry_count!(target)
  end

  @doc """
  Retries the operation associated with the target based on the operation type.

  ## Parameters
    - target: The deployment target to retry.
    - campaign_data: Campaign-specific data including operation type.

  ## Returns
    - `:ok` if the retry operation is successful.
    - `{:error, reason}` if the retry operation fails.
  """
  @impl Core
  def retry_operation(target, campaign_data) do
    retry_target_operation(target, campaign_data.operation_type)
  end

  @doc """
  Retries a specific operation for a deployment target.

  ## Parameters
    - target: The deployment target struct.
    - operation_type: The type of operation to retry (`:deploy`, `:upgrade`, `:start`, `:stop`, `:delete`).

  ## Returns
    - `:ok` if the retry operation is successful.
    - `{:error, reason}` if the retry operation fails.
  """
  def retry_target_operation(target, operation_type) do
    case operation_type do
      :deploy ->
        do_retry_target_operation(target, :send_deployment)

      :upgrade ->
        deployment = Ash.load!(target, :deployment, tenant: target.tenant_id).deployment

        case deployment.state do
          :stopped ->
            # Deployment is already deployed but not started; retry starting
            do_retry_target_operation(target, :start)

          _ ->
            # Deployment not yet deployed or in an unexpected state; retry deployment
            do_retry_target_operation(target, :send_deployment)
        end

      :start ->
        do_retry_target_operation(target, :start)

      :stop ->
        do_retry_target_operation(target, :stop)

      :delete ->
        do_retry_target_operation(target, :delete)

      _ ->
        do_retry_target_operation(target, :send_deployment)
    end
  end

  defp do_retry_target_operation(target, update_action) do
    deployment_result =
      target
      |> Ash.load!(:deployment, tenant: target.tenant_id)
      |> Map.get(:deployment)
      |> Ash.Changeset.for_update(update_action)
      |> Ash.update(tenant: target.tenant_id)

    with {:ok, _deployment} <- deployment_result do
      :ok
    end
  end

  # Error Handling

  @doc """
  Fetches the latest error event for a deployment.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - deployment_id: The ID of the deployment.

  ## Returns
    - The most recent error event for the deployment, or `nil` if none exists.
  """
  def get_latest_error_for_deployment!(tenant_id, deployment_id) do
    Deployment.Event
    |> Ash.Query.filter(deployment_id == ^deployment_id)
    |> Ash.Query.filter(type == :error)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read_first!(tenant: tenant_id)
  end

  # TODO: improve with more specific messages
  @doc """
  Renders a more descriptive error message based on the given reason and device id.

  ## Parameters
    - reason: the error reason.
    - device_id: the device id.

  ## Returns
    - a string describing the error.
  """
  @impl Core
  def error_message(_reason, device_id), do: "An error occurred on device #{inspect(device_id)}"

  @doc """
  Logs the failure message when a deployment operation fails.

  ## Parameters
    - deployment: The failed deployment struct.
    - campaign_data: Campaign data containing the operation_type.

  ## Returns
    - `:ok`
  """
  @impl Core
  def format_operation_failure_log(deployment, campaign_data) do
    latest_error_message =
      case get_latest_error_for_deployment!(deployment.tenant_id, deployment.id) do
        %{message: message} -> message
        nil -> "Could not find any error event."
      end

    operation_type = campaign_data.operation_type

    Logger.notice("Device #{deployment.device_id} #{operation_type} operation failed: #{latest_error_message}")
  end

  @doc """
  Returns `true` if the error indicated by `reason` is considered temporary.

  For now we assume only failures to reach Astarte and server errors are temporary.

  ## Parameters
    - reason: The error reason to check.

  ## Returns
    - `true` if the error is considered temporary (e.g., connection refused, 5xx server errors).
    - `false` if the error is considered permanent.
  """
  @impl Core
  def temporary_error?("connection refused"), do: true
  def temporary_error?(%AstarteAPIError{status: status}) when status in 500..599, do: true
  def temporary_error?(_reason), do: false
end
