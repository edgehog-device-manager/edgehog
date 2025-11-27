#
# This file is part of Edgehog.
#
# Copyright 2023-2025 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout.Core do
  @moduledoc """
  Core implementation for push rollout update campaign execution.

  This module implements the `Edgehog.Campaigns.Executors.Core` behavior for update campaigns,
  providing the business logic for managing OTA (Over-The-Air) updates across target devices.

  ## Terminology

  - **Operation**: In the context of update campaigns, the "operation" refers to an `OTAOperation`
    resource that represents an over-the-air update on a device.
  - **Target**: An `UpdateTarget` represents a device that is part of the campaign.
  - **Mechanism**: The rollout mechanism (push rollout) that controls update behavior.

  ## Update Process

  The module manages the complete lifecycle of OTA updates:
  - Version compatibility checking
  - Update request creation and dispatch
  - Progress tracking and acknowledgment
  - Retry logic for failed updates
  """
  use Edgehog.Campaigns.Executors.Core

  alias Astarte.Client.APIError
  alias Edgehog.Campaigns.Executors.Core
  alias Edgehog.OSManagement
  alias Edgehog.UpdateCampaigns
  alias Edgehog.UpdateCampaigns.UpdateCampaign
  alias Edgehog.UpdateCampaigns.UpdateTarget

  require Ash.Query
  require Logger

  # Campaign Management

  @doc """
  Fetch the `UpdateCampaign` for `campaign_id` in the given tenant.

  Raises if the campaign cannot be found.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.

  ## Returns
    - The update campaign struct.
  """
  @impl Core
  def get_campaign!(tenant_id, campaign_id) do
    UpdateCampaigns.fetch_campaign!(campaign_id, tenant: tenant_id)
  end

  @doc """
  Updates the status of a campaign setting it to `in_progress`.

  Also updates `start_timestamp`.

  ## Parameters
    - campaign: The update campaign struct.
    - now: The current timestamp (defaults to `DateTime.utc_now()`).

  ## Returns
    - The updated campaign struct.
  """
  @impl Core
  def mark_campaign_in_progress!(campaign, now \\ DateTime.utc_now()) do
    UpdateCampaigns.mark_campaign_as_in_progress!(campaign, %{start_timestamp: now})
  end

  @doc """
  Updates the status of a campaign setting it to `:finished` with outcome `:failure`.

  Also updates `completion_timestamp`.

  ## Parameters
    - campaign: The update campaign struct.
    - now: The current timestamp (defaults to `DateTime.utc_now()`).

  ## Returns
    - The updated campaign struct.
  """
  @impl Core
  def mark_campaign_as_failed!(campaign, now \\ DateTime.utc_now()) do
    UpdateCampaigns.mark_campaign_as_failed!(campaign, %{completion_timestamp: now})
  end

  @doc """
  Updates the status of a campaign setting it to `:finished` with outcome `:success`.

  Also updates `completion_timestamp`.

  ## Parameters
    - campaign: The update campaign struct.
    - now: The current timestamp (defaults to `DateTime.utc_now()`).

  ## Returns
    - The updated campaign struct.
  """
  @impl Core
  def mark_campaign_as_successful!(campaign, now \\ DateTime.utc_now()) do
    UpdateCampaigns.mark_campaign_as_successful!(campaign, %{completion_timestamp: now})
  end

  # Campaign Data & Configuration

  @doc """
  Return the rollout mechanism configuration stored on the campaign.
  """
  @impl Core
  def get_mechanism(campaign), do: campaign.rollout_mechanism.value

  @doc """
  Return the persisted campaign status.

  Expected values are `:idle`, `:in_progress` or `:finished`.
  """
  @impl Core
  def get_campaign_status(campaign), do: campaign.status

  @doc """
  Load the small payload of campaign-specific data that the executor needs
  while running. For update campaigns we include:

  - :base_image - the base image to be deployed via OTA updates
  """
  @impl Core
  def load_campaign_data(tenant_id, campaign) do
    %{base_image: get_update_campaign_base_image!(tenant_id, campaign.id)}
  end

  @doc """
  Fetches an update campaign by its ID and tenant ID, raising an error if not found.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.

  ## Returns
    - The update campaign struct.
  """
  def get_update_campaign!(tenant_id, campaign_id) do
    UpdateCampaigns.fetch_campaign!(campaign_id, tenant: tenant_id)
  end

  @doc """
  Returns the BaseImage that belongs to a specific update campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.

  ## Returns
    - The base image associated with the campaign.
  """
  def get_update_campaign_base_image!(tenant_id, campaign_id) do
    campaign_id
    |> UpdateCampaigns.fetch_campaign!(load: :base_image, tenant: tenant_id)
    |> Map.fetch!(:base_image)
  end

  # Campaign Metrics

  @doc """
  Fetches the total target count for a given update campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.

  ## Returns
    - The total number of update targets associated with the campaign.
  """
  @impl Core
  def get_target_count(tenant_id, campaign_id) do
    UpdateCampaign
    |> Ash.get!(campaign_id, tenant: tenant_id, load: [:total_target_count])
    |> Map.fetch!(:total_target_count)
  end

  @doc """
  Fetches the failed target count for a given update campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.

  ## Returns
    - The number of failed update targets associated with the campaign.
  """
  @impl Core
  def get_failed_target_count(tenant_id, campaign_id) do
    UpdateCampaign
    |> Ash.get!(campaign_id, tenant: tenant_id, load: [:failed_target_count])
    |> Map.fetch!(:failed_target_count)
  end

  @doc """
  Fetches the in progress target count for a given update campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.

  ## Returns
    - The number of in progress update targets associated with the campaign.
  """
  @impl Core
  def get_in_progress_target_count(tenant_id, campaign_id) do
    UpdateCampaign
    |> Ash.get!(campaign_id, tenant: tenant_id, load: [:in_progress_target_count])
    |> Map.fetch!(:in_progress_target_count)
  end

  @doc """
  Fetches the available slots for a given update campaign.

  ## Parameters
    - mechanism: The rollout mechanism configuration.
    - in_progress_count: The count of in progress targets.

  ## Returns
    - The number of available slots for update targets.
  """
  @impl Core
  def available_slots(mechanism, in_progress_count) do
    max(0, mechanism.max_in_progress_updates - in_progress_count)
  end

  @doc """
  Checks whether an update campaign has idle targets.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.

  ## Returns
    - `true` if there are idle targets, `false` otherwise.
  """
  @impl Core
  def has_idle_targets?(tenant_id, campaign_id) do
    update_campaign =
      Ash.get!(UpdateCampaign, campaign_id, tenant: tenant_id, load: [:idle_target_count])

    update_campaign.idle_target_count > 0
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
  Fetch an `UpdateTarget` by id for the given tenant.

  Delegates to the `UpdateCampaigns` data layer and will raise if the
  target is not found.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - id: The ID of the update target.

  ## Returns
    - The update target struct.
  """
  @impl Core
  def get_target!(tenant_id, id) do
    UpdateCampaigns.fetch_target!(id, tenant: tenant_id)
  end

  @doc """
  Fetches the update target associated with a given OTA operation ID and campaign ID.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.
    - device_id: The ID of the device.

  ## Returns
    - The update target struct associated with the OTA operation ID and campaign ID.
  """
  @impl Core
  def get_target_for_operation!(tenant_id, campaign_id, device_id) do
    UpdateCampaigns.fetch_target_by_device_and_campaign!(device_id, campaign_id, tenant: tenant_id)
  end

  @doc """
  Lists all the targets of an Update Campaign that have a pending OTA Operation.

  This is useful when resuming an Update Campaign to know which targets need to setup a retry
  timeout.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.

  ## Returns
    - A list of update targets with pending OTA operations.
  """
  @impl Core
  def list_in_progress_targets(tenant_id, campaign_id) do
    UpdateCampaigns.list_targets_with_pending_ota_operation!(campaign_id, tenant: tenant_id)
  end

  @doc """
  Fetches the next valid update target for a given update campaign.

  The next updatable target is chosen with these criteria:
  - It must be idle
  - It must be online
  - It must either not have been attempted before or it has to be the least recently attempted
  target

  This set of constraints guarantees that when we make an attempt on a target that fails with
  a temporary error, given we update latest_attempt, we can just call
  fetch_next_updatable_target/2 again and the next target will be returned.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.
    - _campaign_data: Campaign-specific data (unused).

  ## Returns
    - The next valid target for the campaign, or `nil` if none available.
  """
  @impl Core
  def fetch_next_valid_target(tenant_id, campaign_id, _campaign_data) do
    fetch_next_updatable_target(tenant_id, campaign_id)
  end

  @doc """
  Returns the next updatable target, or `{:error, :not_found}` if no updatable targets are present.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the update campaign.

  ## Returns
    - The next updatable target, or `{:error, :not_found}` if none available.
  """
  def fetch_next_updatable_target(tenant_id, campaign_id) do
    UpdateCampaigns.fetch_next_updatable_target(campaign_id, tenant: tenant_id)
  end

  @doc delegate_to: {UpdateCampaigns, :mark_target_as_failed!, 2}
  @impl Core
  def mark_target_as_failed!(target, now \\ DateTime.utc_now()) do
    UpdateCampaigns.mark_target_as_failed!(target, %{completion_timestamp: now})
  end

  @doc delegate_to: {UpdateCampaigns, :mark_target_as_successful!, 2}
  @impl Core
  def mark_target_as_successful!(target, now \\ DateTime.utc_now()) do
    UpdateCampaigns.mark_target_as_successful!(target, %{completion_timestamp: now})
  end

  @doc delegate_to: {UpdateCampaigns, :update_target_latest_attempt!, 2}
  @impl Core
  def update_target_latest_attempt!(target, latest_attempt) do
    UpdateCampaigns.update_target_latest_attempt!(target, latest_attempt)
  end

  # Operation Execution

  @doc """
  Return the identifier of the underlying operation for a target.

  For update campaigns the operation is an `OTAOperation` and this returns
  the `ota_operation_id` that the executor listens to for updates.
  """
  @impl Core
  def get_operation_id(target), do: target.ota_operation_id

  @doc """
  Executes an OTA update operation on a target device based on campaign data.

  ## Parameters
    - target: The target device where the operation will be performed.
    - campaign_data: Campaign-specific data including base image information.
    - mechanism: The rollout mechanism configuration.

  ## Returns
    - `{:ok, result}` when the operation succeeds.
    - `{:ok, :already_in_desired_state}` if the target is already in the desired state.
    - `{:error, reason}` when the operation fails.
  """
  @impl Core
  def do_operation(target, %{base_image: base_image}, mechanism) do
    with {:ok, target_current_version} <- fetch_target_current_version(target) do
      if needs_update?(target_current_version, base_image) do
        verify_compatibility_and_update(
          target,
          target_current_version,
          base_image,
          mechanism
        )
      else
        {:ok, :already_in_desired_state}
      end
    end
  end

  defp verify_compatibility_and_update(target, target_current_version, base_image, mechanism) do
    with :ok <- verify_compatibility(target_current_version, base_image, mechanism) do
      target = update_target_latest_attempt!(target, DateTime.utc_now())
      start_target_update(target, base_image)
    end
  end

  # Update Operations

  @doc """
  Retrieves the current base image version for a target, querying Astarte.

  ## Parameters
    - target: The update target struct.

  ## Returns
    - `{:ok, %Version{}}` if successful.
    - `{:error, reason}` if the operation fails.
  """
  def fetch_target_current_version(target) do
    with {:ok, target} <- Ash.load(target, device: [:base_image]) do
      version = target.device.base_image && target.device.base_image.version
      parse_version(version)
    end
  end

  defp parse_version(nil) do
    {:error, :missing_version}
  end

  defp parse_version(version) when is_binary(version) do
    case Version.parse(version) do
      {:ok, version} -> {:ok, version}
      :error -> {:error, :invalid_version}
    end
  end

  @doc """
  Returns `true` if the current version of the target does not match the base image version,
  `false` otherwise.

  ## Parameters
    - target_current_version: The current version of the target.
    - base_image: The base image containing the target version.

  ## Returns
    - `true` if an update is needed, `false` otherwise.
  """
  def needs_update?(target_current_version, base_image) do
    base_image_version = Version.parse!(base_image.version)

    # Version.compare/2 ignores build segments, i.e. 1.0.0+build0 and 1.0.0+build1 are
    # considered equal. We manually add a check for that to ensure that the versions
    # are actually exactly the same
    Version.compare(base_image_version, target_current_version) != :eq or
      base_image_version.build != target_current_version.build
  end

  @doc """
  Verify the compatibility between a target and a base image, given the options in the rollout.

  ## Parameters
    - target_current_version: The current version of the target.
    - base_image: The base image to verify compatibility with.
    - mechanism: The rollout mechanism configuration.

  ## Returns
    - `:ok` if the target is compatible with the base image.
    - `{:error, reason}` otherwise.
  """
  def verify_compatibility(target_current_version, base_image, mechanism) do
    force_downgrade = mechanism.force_downgrade
    base_image_version = Version.parse!(base_image.version)
    starting_version_requirement = base_image.starting_version_requirement

    with :ok <- verify_downgrade(target_current_version, base_image_version, force_downgrade) do
      verify_version_requirement(target_current_version, starting_version_requirement)
    end
  end

  defp verify_downgrade(_target_current_version, _base_image, true = _force_downgrade) do
    # If we force downgrade we don't have to check anything here
    :ok
  end

  defp verify_downgrade(target_current_version, base_image_version, false = _force_downgrade) do
    case Version.compare(base_image_version, target_current_version) do
      :gt ->
        :ok

      :lt ->
        {:error, :downgrade_not_allowed}

      :eq ->
        # TODO: Version.compare/2 ignores build segments, i.e. 1.0.0+build0 and 1.0.0+build1 are
        # considered equal. For now, we consider it compatible with a downgrade only if the build
        # segments are the same, otherwise we can't be sure if it's a downgrade or not
        if base_image_version.build == target_current_version.build do
          :ok
        else
          {:error, :ambiguous_version_ordering}
        end
    end
  end

  defp verify_version_requirement(_current_version, nil = _starting_version_requirement) do
    # No explicit version requirement, so everything is ok
    :ok
  end

  defp verify_version_requirement(current_version, starting_version_requirement) do
    if Version.match?(current_version, starting_version_requirement, allow_pre: true) do
      :ok
    else
      {:error, :version_requirement_not_matched}
    end
  end

  @doc """
  Starts the OTA Update for a target, creating an OTA Operation and associating it with the target.

  ## Parameters
    - target: The update target struct.
    - base_image: The base image to be deployed.

  ## Returns
    - `{:ok, target}` if the update is successfully started.
    - `{:error, reason}` if the operation fails.
  """
  def start_target_update(target, base_image) do
    UpdateCampaigns.start_target_update(target, base_image)
  end

  # Operation Subscription & Timeout

  @doc """
  Subscribes to updates for a specific OTA operation.

  ## Parameters
    - operation_id: The ID of the OTA operation to subscribe to.

  ## Returns
    - :ok if the subscription is successful, otherwise raises an error.
  """
  @impl Core
  def subscribe_to_operation_updates!(operation_id) do
    with {:error, reason} <-
           Phoenix.PubSub.subscribe(Edgehog.PubSub, "ota_operations:#{operation_id}") do
      raise reason
    end
  end

  @doc """
  Unsubscribes from updates for a specific OTA operation.

  ## Parameters
    - operation_id: The ID of the OTA operation to unsubscribe from.

  ## Returns
    - `:ok` when the unsubscription is successful.
  """
  @impl Core
  def unsubscribe_to_operation_updates!(operation_id) do
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "ota_operations:#{operation_id}")
  end

  @doc """
  Marks an OTA operation as timed out.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - operation_id: The ID of the OTA operation.

  ## Returns
    - The updated OTA operation struct marked as timed out.
  """
  @impl Core
  def mark_operation_as_timed_out!(tenant_id, operation_id) do
    ota_operation = OSManagement.fetch_ota_operation!(operation_id, tenant: tenant_id)

    case OSManagement.mark_ota_operation_as_timed_out(ota_operation) do
      {:ok, ota_operation} ->
        ota_operation

      {:error, reason} ->
        raise "Could not mark ota_operation #{operation_id} as timed out: #{inspect(reason)}"
    end
  end

  @doc """
  Return the number of milliseconds to wait before considering the pending
  request to the target as timed out.

  ## Parameters
    - target: The update target struct.
    - mechanism: The rollout mechanism configuration.
    - now: The current timestamp (defaults to `DateTime.utc_now()`).

  ## Returns
    - The number of milliseconds remaining before timeout (or `0` if already timed out).
  """
  @impl Core
  def pending_request_timeout_ms(target, mechanism, now \\ DateTime.utc_now()) do
    %UpdateTarget{latest_attempt: %DateTime{} = latest_attempt} = target

    absolute_timeout_ms = to_timeout(second: mechanism.ota_request_timeout_seconds)
    elapsed_from_latest_request_ms = DateTime.diff(now, latest_attempt, :millisecond)

    max(0, absolute_timeout_ms - elapsed_from_latest_request_ms)
  end

  # Retry Logic

  @doc """
  Tests whether the target can be retried based on the mechanism settings.

  ## Parameters
    - target: The considered target.
    - mechanism: The rollout mechanism settings.

  ## Returns
    - `true` if the target has less retries than the number allowed by the
      mechanism settings.
    - `false` otherwise.
  """
  @impl Core
  def can_retry?(target, mechanism) do
    target.retry_count < mechanism.ota_request_retries
  end

  @doc delegate_to: {UpdateCampaigns, :increase_target_retry_count!, 1}
  @impl Core
  def increase_retry_count!(target) do
    UpdateCampaigns.increase_target_retry_count!(target)
  end

  @doc """
  Retries the operation associated with the target based on the operation type.

  ## Parameters
    - target: The update target to retry.
    - _campaign_data: Campaign-specific data (unused).

  ## Returns
    - `:ok` if the retry operation is successful.
    - `{:error, reason}` if the retry operation fails.
  """
  @impl Core
  def retry_operation(target, _campaign_data) do
    retry_target_update(target)
  end

  @doc """
  Resends an OTARequest on Astarte for an existing OTA Operation.

  ## Parameters
    - target: The update target struct.

  ## Returns
    - `:ok` if the retry is successful.
    - `{:error, reason}` if the retry fails.
  """
  def retry_target_update(target) do
    target
    |> Ash.load!(:ota_operation)
    |> Map.fetch!(:ota_operation)
    |> OSManagement.send_update_request()
  end

  # Error Handling

  @doc """
  Returns a printable error message given an error reason and device id.

  ## Parameters
    - reason: The error reason.
    - device_id: The device id.

  ## Returns
    - A string describing the error.
  """
  @impl Core
  def error_message(:version_requirement_not_matched, device_id) do
    "Device #{device_id} does not match version requirement for OTA update"
  end

  def error_message(:downgrade_not_allowed, device_id) do
    "Device #{device_id} cannot be downgraded"
  end

  def error_message(:ambiguous_version_ordering, device_id) do
    "Device #{device_id} has the same version with a different build number. " <>
      "Cannot determine if it's a downgrade, so assuming it is"
  end

  def error_message(:invalid_version, device_id) do
    "Device #{device_id} has an invalid BaseImage version published on Astarte"
  end

  def error_message(:missing_version, device_id) do
    "Device #{device_id} has a null BaseImage version published on Astarte"
  end

  def error_message("connection refused", device_id) do
    # Returned by the Astarte API client if it can't connect to Astarte, assume temporary error
    "Failed to contact Astarte API for device #{device_id}"
  end

  def error_message(%APIError{status: status} = error, device_id) when status in 400..499 do
    # Client error, assume it's always going to fail
    "Device #{device_id} failed Astarte API call: received status #{status} (#{error.response})"
  end

  def error_message(%APIError{status: status} = error, device_id) when status in 500..599 do
    # Server error, assume temporary error
    "Device #{device_id} failed Astarte API call: received status #{status} (#{error.response})"
  end

  def error_message(other, device_id) do
    # Handle unknown error to avoid crashing while logging
    "Device #{device_id} failed with unknown error: #{inspect(other)}"
  end

  @doc """
  Logs the failure message when an OTA operation fails.

  ## Parameters
    - operation: The failed OTA operation struct.
    - campaign_data: Campaign data (unused for update campaigns).

  ## Returns
    - `:ok`
  """
  @impl Core
  def format_operation_failure_log(operation, _campaign_data) do
    Logger.notice("Device #{operation.device_id} failed to update: #{operation.status_code}")
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
  def temporary_error?(%APIError{status: status}) when status in 500..599, do: true
  def temporary_error?(_reason), do: false

  # Helper Functions

  @doc """
  Lists the default associations that should be preloaded for a target or a list of targets.

  ## Returns
    - A list of associations to preload.
  """
  def default_preloads_for_target do
    [
      ota_operation: [:status],
      device: [realm: [:cluster]]
    ]
  end

  @doc """
  Returns true if the OTA Operation is in the :acknowledged state.

  ## Parameters
    - ota_operation: The OTA operation to check.

  ## Returns
    - `true` if the operation is acknowledged, `false` otherwise.
  """
  def ota_operation_acknowledged?(ota_operation) do
    ota_operation.status == :acknowledged
  end

  @doc """
  Returns true if the OTA Operation is in the :success state.

  ## Parameters
    - ota_operation: The OTA operation to check.

  ## Returns
    - `true` if the operation is successful, `false` otherwise.
  """
  def ota_operation_successful?(ota_operation) do
    ota_operation.status == :success
  end

  @doc """
  Returns true if the OTA Operation is in the :failure state.

  ## Parameters
    - ota_operation: The OTA operation to check.

  ## Returns
    - `true` if the operation has failed, `false` otherwise.
  """
  def ota_operation_failed?(ota_operation) do
    ota_operation.status == :failure
  end
end
