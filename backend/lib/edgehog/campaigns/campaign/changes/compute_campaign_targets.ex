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

defmodule Edgehog.Campaigns.Campaign.Changes.ComputeCampaignTargets do
  @moduledoc """
  Computes campaign targets and start campaign executor.

  * Firmware upgrade → all updatable devices for the base image
  * Deploy operations:
    * deploy → all deployable devices
    * start/stop/upgrade/delete → only devices with the release already deployed
  """

  use Ash.Resource.Change

  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.Campaigns.CampaignTarget
  alias Edgehog.Campaigns.Channel
  alias Edgehog.Campaigns.ExecutorSupervisor
  alias Edgehog.Containers.Release

  @deployment_mechanisms [
    :deployment_deploy,
    :deployment_start,
    :deployment_stop,
    :deployment_delete,
    :deployment_upgrade
  ]

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    %{type: campaign_type, value: mechanism} =
      Ash.Changeset.get_attribute(changeset, :campaign_mechanism)

    case resolve_target_devices(changeset, campaign_type, mechanism, tenant) do
      {:ok, target_devices} -> apply_targets(changeset, target_devices, tenant)
      {:error, changeset} -> changeset
    end
  end

  defp resolve_target_devices(changeset, :firmware_upgrade, mechanism, tenant) do
    with {:ok, base_image} <- fetch_base_image(changeset, mechanism, tenant),
         {:ok, channel} <- fetch_channel(changeset, tenant) do
      target_devices =
        channel
        |> Ash.load!(updatable_devices: [base_image: base_image])
        |> Map.fetch!(:updatable_devices)

      {:ok, target_devices}
    end
  end

  defp resolve_target_devices(changeset, action, mechanism, tenant) when action in @deployment_mechanisms do
    with {:ok, release} <- fetch_release(changeset, mechanism, tenant),
         {:ok, channel} <- fetch_channel(changeset, tenant) do
      devices =
        channel
        |> Ash.load!(deployable_devices: [release: release])
        |> Map.fetch!(:deployable_devices)

      {:ok, filter_devices_by_operation(devices, action, release, tenant)}
    end
  end

  defp apply_targets(changeset, [], _tenant) do
    changeset
    |> Ash.Changeset.change_attribute(:status, :finished)
    |> Ash.Changeset.change_attribute(:outcome, :success)
  end

  defp apply_targets(changeset, target_devices, tenant) do
    changeset
    |> Ash.Changeset.change_attribute(:status, :idle)
    |> Ash.Changeset.after_action(fn _changeset, campaign ->
      create_campaign_targets(tenant, campaign, target_devices)
    end)
    |> Ash.Changeset.after_transaction(fn _changeset, result ->
      start_campaign_executor(result)
    end)
  end

  defp fetch_base_image(changeset, campaign_mechanism, tenant) do
    with {:error, _reason} <-
           Ash.get(BaseImage, campaign_mechanism.base_image_id, tenant: tenant) do
      {:error, Ash.Changeset.add_error(changeset, field: :base_image_id, message: "could not be found")}
    end
  end

  defp fetch_release(changeset, campaign_mechanism, tenant) do
    with {:error, _reason} <-
           Ash.get(Release, campaign_mechanism.release_id, tenant: tenant) do
      {:error, Ash.Changeset.add_error(changeset, field: :release_id, message: "could not be found")}
    end
  end

  defp fetch_channel(changeset, tenant) do
    {:ok, channel_id} = Ash.Changeset.fetch_argument(changeset, :channel_id)

    with {:error, _reason} <- Ash.get(Channel, channel_id, tenant: tenant) do
      {:error,
       Ash.Changeset.add_error(changeset,
         field: :channel_id,
         message: "could not be found"
       )}
    end
  end

  defp create_campaign_targets(tenant, campaign, target_devices) do
    campaign_target_maps =
      Enum.map(target_devices, fn device ->
        %{
          status: :idle,
          campaign_id: campaign.id,
          device_id: device.id
        }
      end)

    case Ash.bulk_create(campaign_target_maps, CampaignTarget, :create, tenant: tenant) do
      %Ash.BulkResult{status: :success} ->
        {:ok, campaign}

      _ ->
        {:error, :could_not_create_campaign_targets}
    end
  end

  # For deploy operations, return all deployable devices
  defp filter_devices_by_operation(devices, :deployment_deploy, _release, _tenant), do: devices

  # For other operations (start, stop, upgrade, delete), filter devices that have the release deployed
  defp filter_devices_by_operation(devices, _operation, release, tenant) do
    devices
    |> Ash.load!([:application_deployments], tenant: tenant)
    |> Enum.filter(&has_release_deployed?(&1, release))
  end

  defp has_release_deployed?(device, release) do
    Enum.any?(device.application_deployments, &(&1.release_id == release.id))
  end

  defp start_campaign_executor({:ok, campaign} = _transaction_result) do
    _pid = ExecutorSupervisor.start_executor!(campaign)

    {:ok, campaign}
  end

  defp start_campaign_executor(transaction_result), do: transaction_result
end
