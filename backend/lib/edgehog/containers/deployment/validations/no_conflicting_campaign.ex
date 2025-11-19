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
      {:ok, action_type} when action_type in [:start, :stop, :delete, :upgrade] ->
        {:ok, action_type}

      {:ok, invalid_type} ->
        {:error, "Invalid action_type: #{inspect(invalid_type)}. Must be one of [:start, :stop, :delete, :upgrade]"}

      :error ->
        {:error, "action_type is required"}
    end
  end

  @impl Validation
  def validate(changeset, action_type, _context) do
    deployment = changeset.data
    tenant = Ash.Changeset.get_data(changeset, :tenant_id)

    case fetch_deployment_target(deployment.id, tenant) do
      {:ok, %{deployment_campaign: campaign}} when is_map(campaign) ->
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
    if campaign.operation_type == :upgrade and
         deployment.state == :stopped and
         action_type == :start do
      # This part of code handles retries for upgrade operations.
      :ok
    else
      if campaign.status == :in_progress and campaign.operation_type != action_type do
        {:error, "This deployment is locked due to an ongoing #{format_operation_type(campaign.operation_type)} campaign"}
      else
        :ok
      end
    end
  end

  defp fetch_deployment_target(deployment_id, tenant) do
    case Edgehog.DeploymentCampaigns.DeploymentTarget
         |> Ash.Query.for_read(:read, %{}, tenant: tenant)
         |> Ash.Query.filter(deployment_id == ^deployment_id)
         |> Ash.Query.load(deployment_campaign: [:status, :operation_type])
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
