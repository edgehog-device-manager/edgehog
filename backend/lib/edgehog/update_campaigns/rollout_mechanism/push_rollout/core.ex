#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
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
  alias Astarte.Client.APIError
  alias Edgehog.OSManagement
  alias Edgehog.PubSub
  alias Edgehog.UpdateCampaigns
  alias Edgehog.UpdateCampaigns.UpdateCampaign
  alias Edgehog.UpdateCampaigns.UpdateTarget

  require Ash.Query

  # TODO: Some of these functions can probably be extracted in a separate module, common to all
  # rollouts. Nevertheless, since we currently only have one rollout mechanism, for the time being
  # it's better to leave everything here and leave refactoring for a second moment when a clear
  # structure will emerge from the requirements.

  @doc """
  Gets an UpdateCampaign.
  """
  def get_update_campaign!(tenant_id, update_campaign_id) do
    UpdateCampaigns.fetch_campaign!(update_campaign_id, tenant: tenant_id)
  end

  @doc """
  Returns the number of milliseconds that should be waited before retrying to send the request to
  the target. It returns 0 if the moment to resend the request is already passed.
  This function assumes the passed target already has a pending request in flight.
  """
  def pending_ota_request_timeout_ms(
        update_target,
        rollout,
        now \\ DateTime.utc_now()
      ) do
    %UpdateTarget{latest_attempt: %DateTime{} = latest_attempt} = update_target

    absolute_timeout_ms = :timer.seconds(rollout.ota_request_timeout_seconds)
    elapsed_from_latest_request_ms = DateTime.diff(now, latest_attempt, :millisecond)

    max(0, absolute_timeout_ms - elapsed_from_latest_request_ms)
  end

  @doc """
  Returns the BaseImage that belongs to a specific update_campaign_id
  """
  def get_update_campaign_base_image!(tenant_id, update_campaign_id) do
    UpdateCampaigns.fetch_campaign!(update_campaign_id, load: :base_image, tenant: tenant_id)
    |> Map.fetch!(:base_image)
  end

  @doc """
  This function updates `latest_attempt` for a target. This is useful because when next target is
  retrieved, the results are sorted in ascending order with the `latest_attempt` column, so the
  latest attempted target is retrieved again only after all the other one are attempted at least
  once.
  """
  def update_target_latest_attempt!(target, latest_attempt) do
    UpdateCampaigns.update_target_latest_attempt!(target, latest_attempt)
  end

  @doc """
  Starts the OTA Update for a target, creating an OTA Operation and associating it with the target.
  Returns the updated target.
  """
  def start_target_update(target, base_image) do
    UpdateCampaigns.start_target_update(target, base_image)
  end

  @doc """
  Returns `true` if the target still has some retries left for the rollout, `false` otherwise
  """
  def can_retry?(target, rollout) do
    target.retry_count < rollout.ota_request_retries
  end

  @doc """
  Resends an OTARequest on Astarte for an existing OTA Operation
  """
  def retry_target_update(target) do
    target
    |> Ash.load!(:ota_operation)
    |> Map.fetch!(:ota_operation)
    |> OSManagement.send_update_request()
  end

  @doc """
  Returns an UpdateTarget given its id
  """
  def get_target!(tenant_id, id) do
    UpdateCampaigns.fetch_target!(id, tenant: tenant_id)
  end

  @doc """
  Returns an UpdateTarget given its ota_operation_id
  """
  def get_target_for_ota_operation!(tenant_id, ota_operation_id) do
    UpdateCampaigns.fetch_target_by_ota_operation!(ota_operation_id, tenant: tenant_id)
  end

  @doc """
  Increases the retry count for the target and saves it to the data layer.
  """
  def increase_retry_count!(target) do
    UpdateCampaigns.increase_target_retry_count!(target)
  end

  @doc """
  Returns the number of available update slots given the rollout mechanism and the current number
  of in progress updates.
  """
  def available_update_slots(rollout, in_progress_count) do
    max(0, rollout.max_in_progress_updates - in_progress_count)
  end

  @doc """
  Retrieves the current base image version for a target, querying Astarte.
  Returns `{:ok, %Version{}}` or `{:error, reason}`.
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
  Returns `:ok` if the target is compatible with the base image, `{:error, reason}` otherwise
  """
  def verify_compatibility(target_current_version, base_image, rollout) do
    force_downgrade = rollout.force_downgrade
    base_image_version = base_image.version |> Version.parse!()
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
  Returns the next updatable target, or `{:error, :not_found}` if no updatable targets are
  present.
  The next updatable target is chosen with these criteria:
  - It must be idle
  - It must be online
  - It must either not have been attempted before or it has to be the least recently attempted
  target

  This set of constraints guarantees that when we make an attempt on a target that fails with
  a temporary error, given we update latest_update, we can just call
  fetch_next_updatable_target/2 again and the next target will be returned.
  """
  def fetch_next_updatable_target(tenant_id, update_campaign_id) do
    UpdateCampaigns.fetch_next_updatable_target(update_campaign_id, tenant: tenant_id)
  end

  @doc """
  Lists the default associations that should be preloaded for a target or a list of targets.
  """
  def default_preloads_for_target do
    [
      ota_operation: [:status],
      device: [realm: [:cluster]]
    ]
  end

  @doc """
  Subscribes to receive the events for the OTA Operation with the given id. Raises in case of failure.
  """
  def subscribe_to_ota_operation_updates!(ota_operation_id) do
    with {:error, reason} <- PubSub.subscribe_to_events_for({:ota_operation, ota_operation_id}) do
      raise reason
    end
  end

  @doc """
  Marks the ota_operation as timed out. This will also trigger an update publish on the PubSub.
  """
  def mark_ota_operation_as_timed_out!(tenant_id, ota_operation_id) do
    ota_operation = OSManagement.fetch_ota_operation!(ota_operation_id, tenant: tenant_id)

    case OSManagement.mark_ota_operation_as_timed_out(ota_operation) do
      {:ok, ota_operation} ->
        ota_operation

      {:error, reason} ->
        raise "Could not mark ota_operation #{ota_operation_id} as timed out: #{inspect(reason)}"
    end
  end

  @doc """
  Marks the target with the :failed state in the database.
  """
  def mark_target_as_failed!(target, now \\ DateTime.utc_now()) do
    UpdateCampaigns.mark_target_as_failed!(target, %{completion_timestamp: now})
  end

  @doc """
  Marks the target with the :successful state in the database.
  """
  def mark_target_as_successful!(target, now \\ DateTime.utc_now()) do
    UpdateCampaigns.mark_target_as_successful!(target, %{completion_timestamp: now})
  end

  @doc """
  Returns a printable error message given an error reason.
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
  """
  def temporary_error?("connection refused"), do: true
  def temporary_error?(%APIError{status: status}) when status in 500..599, do: true
  def temporary_error?(_reason), do: false

  @doc """
  Returns true if the OTA Operation is in the :acknowledged state
  """
  def ota_operation_acknowledged?(ota_operation) do
    ota_operation.status == :acknowledged
  end

  @doc """
  Returns true if the OTA Operation is in the :success state
  """
  def ota_operation_successful?(ota_operation) do
    ota_operation.status == :success
  end

  @doc """
  Returns true if the OTA Operation is in the :failure state
  """
  def ota_operation_failed?(ota_operation) do
    ota_operation.status == :failure
  end

  @doc """
  Returns true if the failure threshold for the rollout has been exceeded
  """
  def failure_threshold_exceeded?(target_count, failed_count, rollout) do
    failed_count / target_count * 100 > rollout.max_failure_percentage
  end

  @doc """
  Returns the target count for the Update Campaign
  """
  def get_target_count(tenant_id, update_campaign_id) do
    UpdateCampaign
    |> Ash.get!(update_campaign_id, tenant: tenant_id, load: [:total_target_count])
    |> Map.fetch!(:total_target_count)
  end

  @doc """
  Returns the count of failed targets for the Update Campaign
  """
  def get_failed_target_count(tenant_id, update_campaign_id) do
    UpdateCampaign
    |> Ash.get!(update_campaign_id, tenant: tenant_id, load: [:failed_target_count])
    |> Map.fetch!(:failed_target_count)
  end

  @doc """
  Returns the count of in progress targets for the Update Campaign
  """
  def get_in_progress_target_count(tenant_id, update_campaign_id) do
    UpdateCampaign
    |> Ash.get!(update_campaign_id, tenant: tenant_id, load: [:in_progress_target_count])
    |> Map.fetch!(:in_progress_target_count)
  end

  @doc """
  Returns true if the Update Campaign has still some idle targets.
  If it returns false, all the targets have started their rollout, so the Update Campaign
  will be complete once all the replies arrive (or after the timeouts and retries)
  """
  def has_idle_targets?(tenant_id, update_campaign_id) do
    update_campaign =
      Ash.get!(UpdateCampaign, update_campaign_id, tenant: tenant_id, load: [:idle_target_count])

    update_campaign.idle_target_count > 0
  end

  @doc """
  Updates the status of a campaign setting it to `in_progress`.
  Also updates `start_timestamp`.
  """
  def mark_update_campaign_as_in_progress!(update_campaign, now \\ DateTime.utc_now()) do
    UpdateCampaigns.mark_campaign_as_in_progress!(update_campaign, %{start_timestamp: now})
  end

  @doc """
  Updates the status of a campaign setting it to `:finished` with outcome `:failure`.
  Also updates `completion_timestamp`.
  """
  def mark_update_campaign_as_failed!(update_campaign, now \\ DateTime.utc_now()) do
    UpdateCampaigns.mark_campaign_as_failed!(update_campaign, %{completion_timestamp: now})
  end

  @doc """
  Updates the status of a campaign setting it to `:finished` with outcome `:success`.
  Also updates `completion_timestamp`.
  """
  def mark_update_campaign_as_successful!(update_campaign, now \\ DateTime.utc_now()) do
    UpdateCampaigns.mark_campaign_as_successful!(update_campaign, %{completion_timestamp: now})
  end

  @doc """
  Lists all the targets of an Update Campaign that have a pending OTA Operation.
  This is useful when resuming an Update Campaign to know which targets need to setup a retry
  timeout.
  """
  def list_targets_with_pending_ota_operation(tenant_id, update_campaign_id) do
    UpdateCampaigns.list_targets_with_pending_ota_operation!(update_campaign_id,
      tenant: tenant_id
    )
  end
end
