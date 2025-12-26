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

defmodule Edgehog.Campaigns.Executor.Lazy.Core do
  @moduledoc """
  Core business logic for campaign execution.
  """

  alias Astarte.Client.APIError
  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.CampaignTarget
  alias Edgehog.Error.AstarteAPIError

  # Campaign Management

  @doc """
  Fetch the Campaign for campaign_id in the given tenant.

  Raises if the campaign cannot be found.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.

  ## Returns
    - The campaign struct with preloaded associations.
  """
  def get_campaign!(tenant_id, campaign_id) do
    campaign_id
    |> Campaigns.fetch_campaign!(tenant: tenant_id)
    |> Ash.load!(:total_target_count)
  end

  @doc """
  Marks a campaign as in progress.

  ## Parameters
    - campaign: The campaign struct.

  ## Returns
    - The updated campaign struct marked as in progress.
  """
  def mark_campaign_in_progress!(campaign) do
    Campaigns.mark_campaign_in_progress!(campaign)
  end

  @doc """
  Marks a campaign as failed.

  ## Parameters
    - campaign: The campaign struct.

  ## Returns
    - The updated campaign struct marked as failed.
  """
  def mark_campaign_as_failed!(campaign) do
    Campaigns.mark_campaign_failed!(campaign)
  end

  @doc """
  Marks a campaign as successful.

  ## Parameters
    - campaign: The campaign struct.

  ## Returns
    - The updated campaign struct marked as successful.
  """
  def mark_campaign_as_successful!(campaign) do
    Campaigns.mark_campaign_successful!(campaign)
  end

  # Campaign Data

  @doc """
  Return the persisted campaign status.

  Expected values are `:idle`, `:in_progress` or `:finished`.
  """
  def get_campaign_status(campaign), do: campaign.status

  # Campaign Metrics

  @doc """
  Fetches the total target count for a given campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.

  ## Returns
    - The total number of campaign targets associated with the campaign.
  """
  def get_target_count(tenant_id, campaign_id) do
    campaign_id
    |> Campaigns.fetch_campaign!(tenant: tenant_id)
    |> Ash.load!(:total_target_count)
    |> Map.get(:total_target_count)
  end

  @doc """
  Fetches the failed target count for a given campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.

  ## Returns
    - The number of failed campaign targets associated with the campaign.
  """
  def get_failed_target_count(tenant_id, campaign_id) do
    campaign_id
    |> Campaigns.fetch_campaign!(tenant: tenant_id)
    |> Ash.load!(:failed_target_count)
    |> Map.get(:failed_target_count)
  end

  @doc """
  Fetches the in progress target count for a given campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.

  ## Returns
    - The number of in progress campaign targets associated with the campaign.
  """
  def get_in_progress_target_count(tenant_id, campaign_id) do
    campaign_id
    |> Campaigns.fetch_campaign!(tenant: tenant_id)
    |> Ash.load!(:in_progress_target_count)
    |> Map.get(:in_progress_target_count)
  end

  @doc """
  Fetches the available slots for a given campaign.

  ## Parameters
    - mechanism: The campaign mechanism configuration.
    - in_progress_count: The count of in progress targets.

  ## Returns
    - The number of available slots for campaign targets.
  """
  def available_slots(mechanism, in_progress_count) do
    max(0, mechanism.max_in_progress_operations - in_progress_count)
  end

  @doc """
  Checks whether a campaign has idle targets.

  ## Parameters
    - tenant_id: The ID of the Tenant.
    - campaign_id: The campaign to check.

  ## Returns
    - `true` if there are idle targets, `false` otherwise.
  """
  def has_idle_targets?(tenant_id, campaign_id) do
    campaign =
      Ash.get!(Campaigns.Campaign, campaign_id,
        tenant: tenant_id,
        load: [:idle_target_count]
      )

    campaign.idle_target_count > 0
  end

  # Target Management

  @doc """
  Fetch a CampaignTarget by id for the given tenant.

  Delegates to the Campaigns data layer and will raise if the
  target is not found.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - target_id: The ID of the campaign target.

  ## Returns
    - The campaign target struct.
  """
  def get_target!(tenant_id, target_id) do
    Campaigns.fetch_target!(target_id, tenant: tenant_id)
  end

  @doc """
  Fetches the campaign target associated with a given device ID and campaign ID.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.
    - device_id: The ID of the device.

  ## Returns
    - The campaign target struct associated with the device ID and campaign ID.
  """
  def get_target_for_operation!(tenant_id, campaign_id, device_id) do
    Campaigns.fetch_target_by_device_and_campaign!(
      device_id,
      campaign_id,
      tenant: tenant_id
    )
  end

  @doc """
  Fetches the list of targets for the campaign with `in_progress` state.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.

  ## Returns
    - A list of targets with `in_progress` status.
  """
  def list_in_progress_targets(tenant_id, campaign_id) do
    Campaigns.list_in_progress_targets!(campaign_id,
      tenant: tenant_id
    )
  end

  @doc """
  Marks a campaign target as failed.

  Sets the target's status to failed and records the completion timestamp.

  ## Parameters

    * `target` - The campaign target to mark as failed.
    * `now` - The timestamp to record as completion time. Defaults to the current UTC time.

  ## Returns

  The updated target struct.
  """
  def mark_target_as_failed!(target, now \\ DateTime.utc_now()) do
    Campaigns.mark_target_as_failed!(target, %{completion_timestamp: now})
  end

  @doc """
  Marks a campaign target as successful.

  Sets the target's status to success and records the completion timestamp.

  ## Parameters

    * `target` - The campaign target to mark as successful.
    * `now` - The timestamp to record as completion time. Defaults to the current UTC time.

  ## Returns

  The updated target struct.
  """
  def mark_target_as_successful!(target, now \\ DateTime.utc_now()) do
    Campaigns.mark_target_as_successful!(target, %{completion_timestamp: now})
  end

  # Timeout Management

  @doc """
  Return the number of milliseconds to wait before considering the pending
  request to the target as timed out.

  ## Parameters
    - target: The campaign target struct.
    - mechanism: The campaign mechanism configuration.
    - now: The current timestamp (defaults to `DateTime.utc_now()`).

  ## Returns
    - The number of milliseconds remaining before timeout (or `0` if already timed out).
  """
  def pending_request_timeout_ms(target, mechanism, now \\ DateTime.utc_now()) do
    %CampaignTarget{latest_attempt: %DateTime{} = latest_attempt} = target

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
  def can_retry?(target, mechanism) do
    target.retry_count < mechanism.request_retries
  end

  @doc """
  Increases the retry count of the given target by one.

  ## Parameters
    - target: the considered target.

  ## Returns
    - The updated target struct with increased retry count.
  """
  def increase_retry_count!(target) do
    Campaigns.increase_target_retry_count!(target)
  end

  # Error Handling

  # TODO get_latest_error_for_deployment, format_operation_failure_log

  @doc """
  Returns a printable error message given an error reason and device id.

  ## Parameters
    - reason: The error reason.
    - device_id: The device id.

  ## Returns
    - A string describing the error.
  """
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
  Returns `true` if the error indicated by `reason` is considered temporary.

  For now we assume only failures to reach Astarte and server errors are temporary.

  ## Parameters
    - reason: The error reason to check.

  ## Returns
    - `true` if the error is considered temporary (e.g., connection refused, 5xx server errors).
    - `false` if the error is considered permanent.
  """
  def temporary_error?("connection refused"), do: true
  def temporary_error?(%AstarteAPIError{status: status}) when status in 500..599, do: true
  def temporary_error?(_reason), do: false
end
