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

defmodule Edgehog.DeploymentCampaigns.DeploymentCampaign.Validations.ValidateOperationTypeRequirements do
  @moduledoc """
  Validates that the required arguments are provided based on the operation type.

  For example:
  - `upgrade` operation requires both `release_id` and `target_release_id`
  - `deploy`, `start`, `stop`, `delete` operations require only `release_id`
  """
  use Ash.Resource.Validation

  alias Edgehog.Containers.Release

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, context) do
    operation_type = Ash.Changeset.get_attribute(changeset, :operation_type)

    case operation_type do
      :upgrade -> validate_upgrade_requirements(changeset, context)
      _ -> :ok
    end
  end

  defp validate_upgrade_requirements(changeset, %{tenant: tenant}) do
    {:ok, release_id} = Ash.Changeset.fetch_argument(changeset, :release_id)

    case Ash.Changeset.fetch_argument(changeset, :target_release_id) do
      {:ok, target_release_id} ->
        with {:ok, current_release} <- Ash.get(Release, release_id, tenant: tenant),
             {:ok, target_release} <- Ash.get(Release, target_release_id, tenant: tenant),
             :ok <- validate_same_application(current_release, target_release) do
          validate_is_upgrade(current_release, target_release)
        end

      _ ->
        {:error, field: :target_release_id, message: "is required for upgrade operations"}
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
end
