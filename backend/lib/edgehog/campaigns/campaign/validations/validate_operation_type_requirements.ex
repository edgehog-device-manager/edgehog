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

defmodule Edgehog.Campaigns.Campaign.Validations.ValidateOperationTypeRequirements do
  @moduledoc """
  Validates that the required arguments are provided based on the operation type.

  For example:
  - `firmware_upgrade` operation requires `base_image_id`
  - `deployment_deploy`, `deployment_start`, `deployment_stop`, `deployment_delete`
  operations require only `release_id`
  - `deployment_upgrade` operation requires both `release_id` and `target_release_id`
  """
  use Ash.Resource.Validation

  alias Edgehog.Containers.Release

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, context) do
    %{type: campaign_type, value: campaign_mechanism} =
      Ash.Changeset.get_attribute(changeset, :campaign_mechanism)

    case campaign_type do
      :deployment_upgrade ->
        validate_upgrade_requirements(campaign_mechanism, context)

      :firmware_upgrade ->
        validate_base_image_requirement(campaign_mechanism, context)

      action_type
      when action_type in [
             :deployment_deploy,
             :deployment_start,
             :deployment_stop,
             :deployment_delete
           ] ->
        validate_release_requirement(campaign_mechanism, context)
    end
  end

  defp validate_upgrade_requirements(campaign_mechanism, %{tenant: tenant}) do
    release_id = Map.get(campaign_mechanism, :release_id)
    target_release_id = Map.get(campaign_mechanism, :target_release_id)

    cond do
      is_nil(release_id) ->
        {:error, field: :release_id, message: "is required for upgrade operations"}

      is_nil(target_release_id) ->
        {:error, field: :target_release_id, message: "is required for upgrade operations"}

      true ->
        with {:ok, current_release} <- Ash.get(Release, release_id, tenant: tenant),
             {:ok, target_release} <- Ash.get(Release, target_release_id, tenant: tenant),
             :ok <- validate_same_application(current_release, target_release) do
          validate_is_upgrade(current_release, target_release)
        end
    end
  end

  defp validate_same_application(current_release, target_release) do
    if current_release.application_id == target_release.application_id do
      :ok
    else
      {:error, field: :target_release_id, message: "must belong to the same application as the release"}
    end
  end

  defp validate_is_upgrade(current_release, target_release) do
    with {:ok, current_version} <- parse_version(current_release),
         {:ok, target_version} <- parse_version(target_release) do
      if Version.compare(target_version, current_version) == :gt do
        :ok
      else
        {:error, field: :target_release_id, message: "must be a newer release than the currently installed version"}
      end
    end
  end

  defp parse_version(release) do
    with :error <- release.version |> get_in() |> to_string() |> Version.parse() do
      {:error, :invalid_release}
    end
  end

  defp validate_base_image_requirement(campaign_mechanism, _context) do
    case Map.get(campaign_mechanism, :base_image_id) do
      nil ->
        {:error, field: :base_image_id, message: "is required for firmware upgrade operations"}

      _base_image_id ->
        :ok
    end
  end

  defp validate_release_requirement(campaign_mechanism, _context) do
    case Map.get(campaign_mechanism, :release_id) do
      nil ->
        {:error, field: :release_id, message: "is required for deployment operations"}

      _release_id ->
        :ok
    end
  end
end
