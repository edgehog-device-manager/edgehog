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

defmodule Edgehog.Campaigns.Campaign.Changes.ComputeCampaignTargets do
  @moduledoc """
  Change to compute campaign targets.

  It starts from the channel of the campaign and finds the suitable targets for the campaign.

  For deploy operation, all devices in the channel that match the system model requirements
  are included as targets.

  For other operations (start, stop, upgrade, delete), only devices that already have the
  specified release deployed are included as targets.
  """
  use Ash.Resource.Change

  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.Campaigns.CampaignTarget
  alias Edgehog.Campaigns.Channel
  alias Edgehog.Campaigns.ExecutorSupervisor
  alias Edgehog.Containers.Release

  require Ash.Query

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context

    %{type: campaign_type, value: campaign_mechanism} =
      Ash.Changeset.get_attribute(changeset, :campaign_mechanism)

    target_devices =
      case campaign_type do
        :firmware_upgrade ->
          {:ok, base_image} = fetch_base_image(changeset, campaign_mechanism, tenant)
          {:ok, channel} = fetch_channel(changeset, tenant)
          channel = Ash.load!(channel, updatable_devices: [base_image: base_image])
          channel.updatable_devices

        action
        when action in [
               :deployment_deploy,
               :deployment_start,
               :deployment_stop,
               :deployment_delete,
               :deployment_upgrade
             ] ->
          {:ok, release} = fetch_release(changeset, campaign_mechanism, tenant)
          {:ok, channel} = fetch_channel(changeset, tenant)
          channel = Ash.load!(channel, deployable_devices: [release: release])

          filter_devices_by_operation(channel.deployable_devices, campaign_type, release, tenant)
      end

    if Enum.empty?(target_devices) do
      changeset
      |> Ash.Changeset.change_attribute(:status, :finished)
      |> Ash.Changeset.change_attribute(:outcome, :success)
    else
      changeset
      |> Ash.Changeset.change_attribute(:status, :idle)
      |> Ash.Changeset.after_action(fn _changeset, campaign ->
        create_campaign_targets(tenant, campaign, target_devices)
      end)
      |> Ash.Changeset.after_transaction(fn _changeset, result ->
        start_campaign_executor(result)
      end)
    end
  end

  defp fetch_base_image(changeset, campaign_mechanism, tenant) do
    with {:error, _reason} <-
           Ash.get(BaseImage, campaign_mechanism.base_image_id, tenant: tenant) do
      Ash.Changeset.add_error(changeset, field: :base_image_id, message: "could not be found")
    end
  end

  defp fetch_release(changeset, campaign_mechanism, tenant) do
    with {:error, _reason} <-
           Ash.get(Release, campaign_mechanism.release_id, tenant: tenant) do
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

  defp create_campaign_targets(tenant, campaign, target_devices) do
    campaign_target_maps =
      Enum.map(
        target_devices,
        &%{
          status: :idle,
          campaign_id: campaign.id,
          device_id: &1.id
        }
      )

    %Ash.BulkResult{status: status} =
      Ash.bulk_create(campaign_target_maps, CampaignTarget, :create, tenant: tenant)

    case status do
      :success -> {:ok, campaign}
      _ -> {:error, :could_not_create_campaign_targets}
    end
  end

  defp start_campaign_executor({:ok, campaign} = _transaction_result) do
    _pid = ExecutorSupervisor.start_executor!(campaign)

    {:ok, campaign}
  end

  defp start_campaign_executor(transaction_result), do: transaction_result

  # For deploy operations, return all deployable devices
  defp filter_devices_by_operation(devices, :deployment_deploy, _release, _tenant) do
    devices
  end

  # For other operations (start, stop, upgrade, delete), filter devices that have the release deployed
  defp filter_devices_by_operation(devices, _operation_type, release, tenant) do
    devices_with_release = Ash.load!(devices, [:application_deployments], tenant: tenant)

    Enum.filter(devices_with_release, fn device ->
      has_release_deployed?(device, release)
    end)
  end

  defp has_release_deployed?(device, release) do
    Enum.any?(device.application_deployments, fn deployment ->
      deployment.release_id == release.id
    end)
  end
end
