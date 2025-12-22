#
# This file is part of Edgehog.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Validations.NoConflictingCampaign do
  @moduledoc """
  Validates that a deployment is not part of an in-progress campaign with a different operation type.
  """
  use Ash.Resource.Validation

  alias Ash.Resource.Validation

  require Ash.Query
  require Logger

  @impl Validation
  def init(opts) do
    case Keyword.fetch(opts, :action_type) do
      {:ok, action_type}
      when action_type in [
             :deployment_start,
             :deployment_stop,
             :deployment_delete,
             :deployment_upgrade
           ] ->
        {:ok, action_type}

      {:ok, invalid_type} ->
        {:error,
         "Invalid action_type: #{inspect(invalid_type)}. Must be one of [:deployment_start, :deployment_stop, :deployment_delete, :deployment_upgrade]"}

      :error ->
        {:error, "action_type is required"}
    end
  end

  @impl Validation
  def validate(changeset, action_type, _context) do
    deployment = changeset.data
    tenant = Ash.Changeset.get_data(changeset, :tenant_id)

    case fetch_campaign_target(deployment.id, tenant) do
      {:ok, %{campaign: campaign}} when is_map(campaign) ->
        check_campaign_conflict(campaign, deployment, action_type)

      {:ok, nil} ->
        # No deployment target found, allow the action
        :ok

      {:error, error} ->
        # If we can't load the deployment target, log and allow (safer than blocking)
        Logger.warning("Failed to load deployment_target for conflict validation: #{inspect(error)}")

        :ok
    end
  end

  defp check_campaign_conflict(campaign, deployment, action_type) do
    if campaign.campaign_mechanism.type == :deployment_upgrade and
         deployment.state == :stopped and
         action_type == :deployment_start do
      # This part of code handles retries for upgrade operations.
      :ok
    else
      if campaign.status == :in_progress and campaign.campaign_mechanism.type != action_type do
        {:error,
         "This deployment is locked due to an ongoing #{format_operation_type(campaign.campaign_mechanism.type)} campaign"}
      else
        :ok
      end
    end
  end

  defp fetch_campaign_target(deployment_id, tenant) do
    case Edgehog.Campaigns.CampaignTarget
         |> Ash.Query.for_read(:read, %{}, tenant: tenant)
         |> Ash.Query.filter(deployment_id == ^deployment_id)
         |> Ash.Query.load(campaign: [:status])
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(1)
         |> Ash.read() do
      {:ok, [target | _]} -> {:ok, target}
      {:ok, []} -> {:ok, nil}
      {:error, _} = error -> error
    end
  end

  defp format_operation_type(operation_type) do
    Atom.to_string(operation_type)
  end
end
