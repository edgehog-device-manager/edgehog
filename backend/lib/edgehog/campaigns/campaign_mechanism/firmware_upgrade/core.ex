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
  for: Edgehog.Campaigns.CampaignMechanism.FirmwareUpgrade do
  @moduledoc """
  Core implementation for Firmware Upgrade Operation on firmware upgrade campaign execution.

  This module implements the `Edgehog.Campaigns.CampaignMechanism.Core` behavior for firmware upgrade campaigns,
  providing the business logic for managing firmware upgrades across target devices.
  """

  alias Edgehog.Campaigns
  alias Edgehog.OSManagement

  require Logger

  def get_operation_id(_mechanism, target), do: target.ota_operation_id

  @doc """
  Marks an OTA operation as timed out.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - operation_id: The ID of the OTA operation.

  ## Returns
    - The updated OTA operation struct marked as timed out.
  """
  def mark_operation_as_timed_out!(_mechanism, operation_id, tenant_id) do
    ota_operation = OSManagement.fetch_ota_operation!(operation_id, tenant: tenant_id)

    case OSManagement.mark_ota_operation_as_timed_out(ota_operation) do
      {:ok, ota_operation} ->
        ota_operation

      {:error, reason} ->
        raise "Could not mark ota_operation #{operation_id} as timed out: #{inspect(reason)}"
    end
  end

  def subscribe_to_operation_updates!(_mechanism, operation_id) do
    with {:error, reason} <-
           Phoenix.PubSub.subscribe(Edgehog.PubSub, "ota_operations:#{operation_id}") do
      raise reason
    end
  end

  def unsubscribe_to_operation_updates!(_mechanism, operation_id) do
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "ota_operations:#{operation_id}")
  end

  def fetch_next_valid_target(_mechanism, campaign_id, tenant_id) do
    Campaigns.fetch_next_valid_target(campaign_id, tenant: tenant_id)
  end

  def do_operation(mechanism, target) do
    with {:ok, target_current_version} <- fetch_target_current_version(target) do
      if needs_update?(target_current_version, mechanism.base_image) do
        verify_compatibility_and_update(
          target,
          target_current_version,
          mechanism.base_image,
          mechanism
        )
      else
        {:ok, :already_in_desired_state}
      end
    end
  end

  defp verify_compatibility_and_update(target, target_current_version, base_image, mechanism) do
    with :ok <- verify_compatibility(target_current_version, base_image, mechanism) do
      target = Campaigns.update_target_latest_attempt!(target, DateTime.utc_now())
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
    Campaigns.start_fw_upgrade(target, base_image)
  end

  @doc """
  Resends an OTARequest on Astarte for an existing OTA Operation.

  ## Parameters
    - _mechanism: The campaign mechanism (unused).
    - target: The update target struct.

  ## Returns
    - `:ok` if the retry operation is successful.
    - `{:error, reason}` if the retry operation fails.
  """
  def retry_operation(_mechanism, target) do
    target
    |> Ash.load!(:ota_operation)
    |> Map.fetch!(:ota_operation)
    |> OSManagement.send_update_request()
  end

  def get_mechanism(_mechanism, campaign) do
    mechanism =
      campaign
      |> Ash.load!(campaign_mechanism: [firmware_upgrade: [:base_image]])
      |> Map.get(:campaign_mechanism)

    mechanism.value
  end
end
