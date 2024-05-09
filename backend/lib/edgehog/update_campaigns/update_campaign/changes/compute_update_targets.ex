#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.UpdateCampaign.Changes.ComputeUpdateTargets do
  use Ash.Resource.Change

  require Ash.Query

  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.UpdateCampaigns.UpdateChannel
  alias Edgehog.UpdateCampaigns.UpdateTarget

  @impl true
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context

    with {:ok, base_image} <- fetch_base_image(changeset, tenant),
         {:ok, update_channel} <- fetch_update_channel(changeset, tenant) do
      update_channel = Ash.load!(update_channel, updatable_devices: [base_image: base_image])

      updatable_devices = update_channel.updatable_devices

      if Enum.empty?(updatable_devices) do
        changeset
        |> Ash.Changeset.change_attribute(:status, :finished)
        |> Ash.Changeset.change_attribute(:outcome, :success)
      else
        changeset
        |> Ash.Changeset.change_attribute(:status, :idle)
        |> Ash.Changeset.after_action(fn _changeset, update_campaign ->
          create_update_targets(tenant, update_campaign, updatable_devices)
        end)
        |> Ash.Changeset.after_transaction(fn _changeset, result ->
          start_campaign_executor(result)
        end)
      end
    end
  end

  defp fetch_base_image(changeset, tenant) do
    {:ok, base_image_id} = Ash.Changeset.fetch_argument(changeset, :base_image_id)

    with {:error, _reason} <- Ash.get(BaseImage, base_image_id, tenant: tenant) do
      Ash.Changeset.add_error(changeset, field: :base_image_id, message: "could not be found")
    end
  end

  defp fetch_update_channel(changeset, tenant) do
    {:ok, update_channel_id} = Ash.Changeset.fetch_argument(changeset, :update_channel_id)

    with {:error, _reason} <- Ash.get(UpdateChannel, update_channel_id, tenant: tenant) do
      Ash.Changeset.add_error(changeset, field: :update_channel_id, message: "could not be found")
    end
  end

  defp create_update_targets(tenant, update_campaign, updatable_devices) do
    update_target_maps =
      Enum.map(
        updatable_devices,
        &%{
          status: :idle,
          update_campaign_id: update_campaign.id,
          device_id: &1.id
        }
      )

    %Ash.BulkResult{status: status} =
      Ash.bulk_create(update_target_maps, UpdateTarget, :create, tenant: tenant)

    case status do
      :success -> {:ok, update_campaign}
      _ -> {:error, :could_not_create_update_targets}
    end
  end

  defp start_campaign_executor({:ok, update_campaign} = _transaction_result) do
    # TODO: start the Executor on the update campaign

    {:ok, update_campaign}
  end

  defp start_campaign_executor(transaction_result), do: transaction_result
end
