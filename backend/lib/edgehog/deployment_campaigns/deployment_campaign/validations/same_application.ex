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

defmodule Edgehog.DeploymentCampaigns.DeploymentCampaign.Validations.SameApplication do
  @moduledoc false
  use Ash.Resource.Validation

  alias Edgehog.Containers.Release

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, %{tenant: tenant}) do
    campaign_type = Ash.Changeset.get_attribute(changeset, :operation_type)

    case campaign_type do
      :upgrade ->
        validate_same_application(changeset, tenant)

      _ ->
        :ok
    end
  end

  defp validate_same_application(changeset, tenant) do
    release_id = Ash.Changeset.get_argument(changeset, :release_id)
    target_release_id = Ash.Changeset.get_argument(changeset, :target_release_id)

    with {:ok, release} <- fetch_release(release_id, tenant),
         {:ok, target_release} <- fetch_release(target_release_id, tenant) do
      case target_release do
        %Release{} ->
          if release.application_id == target_release.application_id do
            :ok
          else
            {:error,
             field: :target_release_id, message: "must belong to the same application as the currently installed release."}
          end

        nil ->
          :ok
      end
    end
  end

  defp fetch_release(nil = _release_id, _tenant), do: {:ok, nil}

  defp fetch_release(release_id, tenant), do: Ash.get(Release, release_id, tenant: tenant, error?: false)
end
