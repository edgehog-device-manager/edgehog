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

defprotocol Edgehog.Campaigns.CampaignMechanism.Core do
  @moduledoc """
  Protocol defining the core functions that a campaign mechanism must implement.

  These functions cover the essential operations needed to manage and execute campaigns,
  including operation tracking, target management, and notification handling.
  """

  @fallback_to_any true

  def get_campaign!(mechanism, tenant_id, campaign_id)
  def mark_campaign_in_progress!(mechanism, campaign, now \\ DateTime.utc_now())
  def mark_campaign_as_failed!(mechanism, campaign, now \\ DateTime.utc_now())
  def mark_campaign_as_successful!(mechanism, campaign, now \\ DateTime.utc_now())
  def mark_campaign_as_paused!(mechanism, campaign)
  def get_campaign_status(mechanism, campaign)
  def get_target_count(mechanism, tenant_id, campaign_id)
  def get_failed_target_count(mechanism, tenant_id, campaign_id)
  def get_in_progress_target_count(mechanism, tenant_id, campaign_id)
  def available_slots(mechanism, in_progress_count)
  def has_idle_targets?(mechanism, tenant_id, campaign_id)
  def get_target!(mechanism, tenant_id, target_id)
  def get_target_for_operation!(mechanism, tenant_id, campaign_id, device_id)
  def list_in_progress_targets(mechanism, tenant_id, campaign_id)
  def mark_target_as_failed!(mechanism, target, now \\ DateTime.utc_now())
  def mark_target_as_successful!(mechanism, target, now \\ DateTime.utc_now())
  def update_target_latest_attempt(mechanism, target, now \\ DateTime.utc_now())
  def pending_request_timeout_ms(mechanism, target, now \\ DateTime.utc_now())
  def can_retry?(mechanism, target)
  def increase_retry_count!(mechanism, target)
  def format_operation_failure_log(mechanism, operation)
  def error_message(mechanism, reason, device_id)
  def temporary_error?(mechanism, reason)
  def get_operation_id(mechanism, target)
  def mark_operation_as_timed_out!(mechanism, operation_id, tenant_id)
  def subscribe_to_operation_updates!(mechanism, operation_id)
  def unsubscribe_to_operation_updates!(mechanism, operation_id)
  def fetch_next_valid_target(mechanism, campaign_id, tenant_id)
  def do_operation(mechanism, target)
  def retry_operation(mechanism, target)
  def get_mechanism(mechanism, campaign)
end

defimpl Edgehog.Campaigns.CampaignMechanism.Core, for: Any do
  @moduledoc """
  Default implementation of the CampaignMechanism.Core protocol for any data type.

  This provides the core business logic for campaign execution.
  """

  alias Astarte.Client.APIError
  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.CampaignTarget

  require Logger

  # Campaign Management

  @doc """
  Fetch the Campaign for campaign_id in the given tenant.

  Raises if the campaign cannot be found.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.

  ## Returns
    - The campaign struct with preloaded associations.
  """
  def get_campaign!(_mechanism, tenant_id, campaign_id) do
    campaign_id
    |> Campaigns.fetch_campaign!(tenant: tenant_id)
    |> Ash.load!(:total_target_count)
  end

  @doc """
  Marks a campaign as in progress.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - campaign: The campaign struct.
    - now: The timestamp to set as start time. Defaults to `DateTime.utc_now()`.

  ## Returns
    - The updated campaign struct marked as in progress.
  """
  def mark_campaign_in_progress!(_mechanism, campaign, now \\ DateTime.utc_now()) do
    Campaigns.mark_campaign_in_progress!(campaign, %{start_timestamp: now})
  end

  @doc """
  Marks a campaign as failed.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - campaign: The campaign struct.
    - now: The timestamp to set as completion time. Defaults to `DateTime.utc_now()`.

  ## Returns
    - The updated campaign struct marked as failed.
  """
  def mark_campaign_as_failed!(_mechanism, campaign, now \\ DateTime.utc_now()) do
    Campaigns.mark_campaign_failed!(campaign, %{completion_timestamp: now})
  end

  @doc """
  Marks a campaign as successful.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - campaign: The campaign struct.
    - now: The timestamp to set as completion time. Defaults to `DateTime.utc_now()`.

  ## Returns
    - The updated campaign struct marked as successful.
  """
  def mark_campaign_as_successful!(_mechanism, campaign, now \\ DateTime.utc_now()) do
    Campaigns.mark_campaign_successful!(campaign, %{completion_timestamp: now})
  end

  @doc """
  Marks a campaign as paused.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - campaign: The campaign struct.

  ## Returns
    - The updated campaign struct marked as paused.
  """
  def mark_campaign_as_paused!(_mechanism, campaign) do
    Campaigns.mark_campaign_paused!(campaign)
  end

  # Campaign Data

  @doc """
  Return the persisted campaign status.

  Expected values are `:idle`, `:in_progress`, `:pausing`, `:paused` or `:finished`.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - campaign: The campaign struct.

  ## Returns
    - The campaign status atom.
  """
  def get_campaign_status(_mechanism, campaign), do: campaign.status

  # Campaign Metrics

  @doc """
  Fetches the total target count for a given campaign.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.

  ## Returns
    - The total number of campaign targets associated with the campaign.
  """
  def get_target_count(_mechanism, tenant_id, campaign_id) do
    campaign_id
    |> Campaigns.fetch_campaign!(tenant: tenant_id)
    |> Ash.load!(:total_target_count)
    |> Map.get(:total_target_count)
  end

  @doc """
  Fetches the failed target count for a given campaign.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.

  ## Returns
    - The number of failed campaign targets associated with the campaign.
  """
  def get_failed_target_count(_mechanism, tenant_id, campaign_id) do
    campaign_id
    |> Campaigns.fetch_campaign!(tenant: tenant_id)
    |> Ash.load!(:failed_target_count)
    |> Map.get(:failed_target_count)
  end

  @doc """
  Fetches the in progress target count for a given campaign.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.

  ## Returns
    - The number of in progress campaign targets associated with the campaign.
  """
  def get_in_progress_target_count(_mechanism, tenant_id, campaign_id) do
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
    - mechanism: The campaign mechanism (unused in default implementation).
    - tenant_id: The ID of the Tenant.
    - campaign_id: The campaign to check.

  ## Returns
    - `true` if there are idle targets, `false` otherwise.
  """
  def has_idle_targets?(_mechanism, tenant_id, campaign_id) do
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
    - mechanism: The campaign mechanism (unused in default implementation).
    - tenant_id: The ID of the tenant.
    - target_id: The ID of the campaign target.

  ## Returns
    - The campaign target struct.
  """
  def get_target!(_mechanism, tenant_id, target_id) do
    Campaigns.fetch_target!(target_id, tenant: tenant_id)
  end

  @doc """
  Fetches the campaign target associated with a given device ID and campaign ID.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the campaign.
    - device_id: The ID of the device.

  ## Returns
    - The campaign target struct associated with the device ID and campaign ID.
  """
  def get_target_for_operation!(_mechanism, tenant_id, campaign_id, device_id) do
    Campaigns.fetch_target_by_device_and_campaign!(
      device_id,
      campaign_id,
      tenant: tenant_id
    )
  end

  @doc """
  Marks a campaign target as failed.

  Sets the target's status to failed and records the completion timestamp.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - target: The campaign target to mark as failed.
    - now: The timestamp to record as completion time. Defaults to `DateTime.utc_now()`.

  ## Returns
    - The updated target struct.
  """
  def mark_target_as_failed!(_mechanism, target, now \\ DateTime.utc_now()) do
    Campaigns.mark_target_as_failed!(target, %{completion_timestamp: now})
  end

  @doc """
  Marks a campaign target as successful.

  Sets the target's status to success and records the completion timestamp.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - target: The campaign target to mark as successful.
    - now: The timestamp to record as completion time. Defaults to `DateTime.utc_now()`.

  ## Returns
    - The updated target struct.
  """
  def mark_target_as_successful!(_mechanism, target, now \\ DateTime.utc_now()) do
    Campaigns.mark_target_as_successful!(target, %{completion_timestamp: now})
  end

  @doc """
  Updates the latest attempt timestamp for a campaign target.

  Updates the `latest_attempt` field of a target to the current time,
  tracking when the last update attempt was made for the target in a campaign.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - target: The campaign target struct to update.
    - now: The timestamp to set as the latest attempt. Defaults to `DateTime.utc_now()`.

  ## Returns
    - The updated target struct.
  """
  def update_target_latest_attempt(_mechanism, target, now \\ DateTime.utc_now()) do
    Campaigns.update_target_latest_attempt!(target, now)
  end

  # Timeout Management

  @doc """
  Return the number of milliseconds to wait before considering the pending
  request to the target as timed out.

  ## Parameters
    - mechanism: The campaign mechanism configuration.
    - target: The campaign target struct.
    - now: The current timestamp. Defaults to `DateTime.utc_now()`.

  ## Returns
    - The number of milliseconds remaining before timeout (or `0` if already timed out).
  """
  def pending_request_timeout_ms(mechanism, target, now \\ DateTime.utc_now()) do
    %CampaignTarget{latest_attempt: %DateTime{} = latest_attempt} = target

    absolute_timeout_ms = to_timeout(second: mechanism.request_timeout_seconds)
    elapsed_from_latest_request_ms = DateTime.diff(now, latest_attempt, :millisecond)

    max(0, absolute_timeout_ms - elapsed_from_latest_request_ms)
  end

  # Retry Logic

  @doc """
  Tests whether the target can be retried based on the mechanism settings.

  ## Parameters
    - mechanism: The campaign mechanism settings.
    - target: The campaign target to check.

  ## Returns
    - `true` if the target has fewer retries than the number allowed by the mechanism settings.
    - `false` otherwise.
  """
  def can_retry?(mechanism, target) do
    target.retry_count < mechanism.request_retries
  end

  @doc """
  Increases the retry count of the given target by one.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - target: The campaign target to update.

  ## Returns
    - The updated target struct with increased retry count.
  """
  def increase_retry_count!(_mechanism, target) do
    Campaigns.increase_target_retry_count!(target)
  end

  # Error Handling

  @doc """
  Formats and logs a failure message for an operation.

  Logs the device ID and status code.

  ## Parameters
    - mechanism: The campaign mechanism containing the type information.
    - operation: The operation struct.

  ## Returns
    - `:ok` (this function is called for its side effect of logging).
  """
  def format_operation_failure_log(mechanism, operation) do
    Logger.notice(
      "Device #{operation.device_id} #{mechanism.type} operation failed: status code #{operation.status_code}"
    )
  end

  @doc """
  Returns a printable error message given an error reason and device id.

  This default implementation handles generic errors that apply to all mechanism types.
  Specific mechanisms should override this for their own error types.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - reason: The error reason (atom, string, or `APIError` struct).
    - device_id: The device ID.

  ## Returns
    - A string describing the error.
  """
  def error_message(_mechanism, "connection refused", device_id) do
    # Returned by the Astarte API client if it can't connect to Astarte, assume temporary error
    "Failed to contact Astarte API for device #{device_id}"
  end

  def error_message(_mechanism, %APIError{status: status} = error, device_id) when status in 400..499 do
    # Client error, assume it's always going to fail
    "Device #{device_id} failed Astarte API call: received status #{status} (#{error.response})"
  end

  def error_message(_mechanism, %APIError{status: status} = error, device_id) when status in 500..599 do
    # Server error, assume temporary error
    "Device #{device_id} failed Astarte API call: received status #{status} (#{error.response})"
  end

  def error_message(_mechanism, other, device_id) do
    # Handle unknown error to avoid crashing while logging
    "Device #{device_id} failed with unknown error: #{inspect(other)}"
  end

  @doc """
  Returns `true` if the error indicated by `reason` is considered temporary.

  For now we assume only failures to reach Astarte and server errors are temporary.

  ## Parameters
    - mechanism: The campaign mechanism (unused in default implementation).
    - reason: The error reason to check.

  ## Returns
    - `true` if the error is considered temporary (e.g., connection refused, 5xx server errors).
    - `false` if the error is considered permanent.
  """
  def temporary_error?(_mechanism, "connection refused"), do: true
  def temporary_error?(_mechanism, %APIError{status: status}) when status in 500..599, do: true
  def temporary_error?(_mechanism, _reason), do: false

  # Mechanism-Specific Functions

  # The following functions must be implemented by specific mechanism types.
  # These are stub implementations that raise errors if called on the fallback.

  def get_operation_id(_mechanism, _target) do
    raise "get_operation_id/2 must be implemented by specific mechanism"
  end

  def mark_operation_as_timed_out!(_mechanism, _operation_id, _tenant_id) do
    raise "mark_operation_as_timed_out!/3 must be implemented by specific mechanism"
  end

  def subscribe_to_operation_updates!(_mechanism, _operation_id) do
    raise "subscribe_to_operation_updates!/2 must be implemented by specific mechanism"
  end

  def unsubscribe_to_operation_updates!(_mechanism, _operation_id) do
    raise "unsubscribe_to_operation_updates!/2 must be implemented by specific mechanism"
  end

  def fetch_next_valid_target(_mechanism, _campaign_id, _tenant_id) do
    raise "fetch_next_valid_target/3 must be implemented by specific mechanism"
  end

  def do_operation(_mechanism, _target) do
    raise "do_operation/2 must be implemented by specific mechanism"
  end

  def retry_operation(_mechanism, _target) do
    raise "retry_operation/2 must be implemented by specific mechanism"
  end

  def get_mechanism(_mechanism, _campaign) do
    raise "get_mechanism/2 must be implemented by specific mechanism"
  end

  def list_in_progress_targets(_mechanism, _tenant_id, _campaign_id) do
    raise "list_in_progress_targets/3 must be implemented by specific mechanism"
  end
end
