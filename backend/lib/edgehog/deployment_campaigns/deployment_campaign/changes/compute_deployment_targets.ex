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

defmodule Edgehog.DeploymentCampaigns.DeploymentCampaign.Changes.ComputeDeploymentTargets do
  @moduledoc """
  Change to compute deployment targets.

  It starts from the channel of the campaign and finds the suitable targets for the campaign.
  """
  use Ash.Resource.Change

  alias Edgehog.Campaigns.Channel
  alias Edgehog.Campaigns.ExecutorSupervisor
  alias Edgehog.Containers.Release
  alias Edgehog.DeploymentCampaigns.DeploymentTarget

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context

    with {:ok, release} <- fetch_release(changeset, tenant),
         {:ok, channel} <- fetch_channel(changeset, tenant) do
      channel = Ash.load!(channel, deployable_devices: [release: release])

      deployable_devices = channel.deployable_devices

      if Enum.empty?(deployable_devices) do
        changeset
        |> Ash.Changeset.change_attribute(:status, :finished)
        |> Ash.Changeset.change_attribute(:outcome, :success)
      else
        changeset
        |> Ash.Changeset.change_attribute(:status, :idle)
        |> Ash.Changeset.after_action(fn _changeset, deployment_campaign ->
          create_deployment_targets(tenant, deployment_campaign, deployable_devices)
        end)
        |> Ash.Changeset.after_transaction(fn _changeset, result ->
          start_campaign_executor(result)
        end)
      end
    end
  end

  defp fetch_release(changeset, tenant) do
    {:ok, release_id} = Ash.Changeset.fetch_argument(changeset, :release_id)

    with {:error, _reason} <- Ash.get(Release, release_id, tenant: tenant) do
      Ash.Changeset.add_error(changeset, field: :release_id, message: "could not be found")
    end
  end

  defp fetch_channel(changeset, tenant) do
    {:ok, channel_id} = Ash.Changeset.fetch_argument(changeset, :channel_id)

    with {:error, _reason} <- Ash.get(Channel, channel_id, tenant: tenant) do
      Ash.Changeset.add_error(changeset,
        field: :channel_id,
        message: "could not be found"
      )
    end
  end

  defp create_deployment_targets(tenant, deployment_campaign, deployable_devices) do
    deployment_target_maps =
      Enum.map(
        deployable_devices,
        &%{
          status: :idle,
          deployment_campaign_id: deployment_campaign.id,
          device_id: &1.id
        }
      )

    %Ash.BulkResult{status: status} =
      Ash.bulk_create(deployment_target_maps, DeploymentTarget, :create, tenant: tenant)

    case status do
      :success -> {:ok, deployment_campaign}
      _ -> {:error, :could_not_create_deployment_targets}
    end
  end

  defp start_campaign_executor({:ok, deployment_campaign} = _transaction_result) do
    _pid = ExecutorSupervisor.start_executor!(deployment_campaign)

    {:ok, deployment_campaign}
  end

  defp start_campaign_executor(transaction_result), do: transaction_result
end
