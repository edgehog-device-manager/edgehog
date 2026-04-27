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
  for: Edgehog.Campaigns.CampaignMechanism.FileDownload do
  @moduledoc """
  Core implementation for File Download Operation on file download campaign execution.

  This module implements the `Edgehog.Campaigns.CampaignMechanism.Core` behavior for file download campaigns,
  providing the business logic for managing file downloads across target devices.
  """

  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.CampaignMechanism.Core.Any
  alias Edgehog.Files

  require Logger

  # Operation Tracking

  @doc """
  Returns the file download request ID as the operation identifier for tracking.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - target: The campaign target struct.

  ## Returns
    - The file download request ID from the target.
  """
  def get_operation_id(_mechanism, target), do: target.file_download_request_id

  @doc """
  Marks a file download request operation as timed out.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - operation_id: The ID of the file download request operation.
    - tenant_id: The ID of the tenant.

  ## Returns
    - The updated file download request struct marked as timed out.
  """
  def mark_operation_as_timed_out!(_mechanism, operation_id, tenant_id) do
    file_download_request = Files.fetch_file_download_request!(operation_id, tenant: tenant_id)

    case Files.set_file_download_response(
           file_download_request,
           %{status: :failed, response_code: -1, response_message: "Request timed out"},
           tenant: tenant_id
         ) do
      {:ok, file_download_request} ->
        file_download_request

      {:error, reason} ->
        raise "Could not mark file_download_request #{operation_id} as timed out: #{inspect(reason)}"
    end
  end

  @doc """
  Subscribes to file download request operation updates via PubSub.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - operation_id: The ID of the file download request operation.

  ## Returns
    - `:ok` on success.
    - Raises an error on failure.
  """
  def subscribe_to_operation_updates!(_mechanism, operation_id) do
    with {:error, reason} <-
           Phoenix.PubSub.subscribe(Edgehog.PubSub, "file_download_requests:#{operation_id}") do
      raise reason
    end
  end

  @doc """
  Unsubscribes from file download request operation updates via PubSub.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - operation_id: The ID of the file download request operation.

  ## Returns
    - `:ok`
  """
  def unsubscribe_to_operation_updates!(_mechanism, operation_id) do
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "file_download_requests:#{operation_id}")
  end

  # Target Management

  @doc """
  Fetches the next valid target for file download.

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
    Campaigns.list_targets_with_pending_file_download_request!(campaign_id, tenant: tenant_id)
  end

  # Operation Execution

  @doc """
  Performs the file download operation for a given mechanism and target device.

  This function orchestrates the file download process by:
  1. Creating a file download request for the target device
  2. Sending the request to the device via Astarte

  ## Parameters

    - `mechanism` - The campaign mechanism struct containing the file and download configuration
    - `target` - The target device to perform the file download on

  ## Returns

    - `{:ok, target}` - When the file download request is successfully created and sent
    - `{:error, reason}` - When the operation fails
  """
  def do_operation(mechanism, target) do
    target = Campaigns.update_target_latest_attempt!(target, DateTime.utc_now())
    start_file_download(target, mechanism)
  end

  @doc """
  Starts the file download for a target, creating a FileDownloadRequest and associating it with the target.

  ## Parameters
    - target: The campaign target struct.
    - mechanism: The campaign mechanism containing the file configuration.

  ## Returns
    - `{:ok, target}` if the file download is successfully started.
    - `{:error, reason}` if the operation fails.
  """
  def start_file_download(target, mechanism) do
    # The file is already loaded in mechanism via get_mechanism
    Campaigns.start_file_download(target, mechanism.file, mechanism)
  end

  @doc """
  Retries the file download operation for a target.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - target: The campaign target struct.

  ## Returns
    - `:ok` if the retry is successful.
    - `{:error, reason}` if the retry fails.
  """
  def retry_operation(_mechanism, target) do
    target
    |> Ash.load!(:file_download_request)
    |> Map.fetch!(:file_download_request)
    |> Files.send_file_download_request()
  end

  # Mechanism Configuration

  @doc """
  Loads and returns the full mechanism configuration from a campaign.

  ## Parameters
    - mechanism: The campaign mechanism struct.
    - campaign: The campaign struct to load the mechanism from.

  ## Returns
    - The fully loaded file download mechanism with file data.
  """
  def get_mechanism(_mechanism, campaign) do
    mechanism =
      campaign
      |> Ash.load!(campaign_mechanism: [file_download: [:file]])
      |> Map.get(:campaign_mechanism)

    mechanism.value
  end

  # Error Handling

  @doc """
  Formats and logs a failure message for an operation.

  Logs the device ID and response code.

  ## Parameters
    - mechanism: The campaign mechanism containing the type information.
    - operation: The operation struct (FileDownloadRequest).

  ## Returns
    - `:ok` (this function is called for its side effect of logging).
  """
  def format_operation_failure_log(mechanism, operation) do
    Logger.notice(
      "Device #{operation.device_id} #{mechanism.type} operation failed: response code #{operation.response_code}, message: #{operation.response_message}"
    )
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

  defdelegate mark_campaign_as_paused!(mechanism, campaign),
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

  defdelegate error_message(mechanism, reason, device_id),
    to: Any
end
