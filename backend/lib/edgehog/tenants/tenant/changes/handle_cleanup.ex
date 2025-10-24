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

defmodule Edgehog.Tenants.Tenant.Changes.HandleCleanup do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.BaseImages
  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.Devices
  alias Edgehog.Devices.SystemModel
  alias Edgehog.OSManagement
  alias Edgehog.OSManagement.OTAOperation

  require Ash.Query
  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    tenant = changeset.data

    system_model_ids =
      SystemModel
      |> Ash.read!(tenant: tenant)
      |> Enum.map(& &1.id)

    base_image_ids =
      BaseImage
      |> Ash.read!(tenant: tenant)
      |> Enum.map(& &1.id)

    manual_ota_ids =
      OTAOperation
      |> Ash.Query.filter(manual?)
      |> Ash.read!(tenant: tenant)
      |> Enum.map(& &1.id)

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, tenant} <- result do
        try do
          cleanup_system_models(system_model_ids, tenant)
          cleanup_base_images(base_image_ids, tenant)
          cleanup_ephimeral_images(manual_ota_ids, tenant)
        catch
          signal, error ->
            Logger.error("""
            Tenant cleanup was not completed:
            recived signal #{inspect(signal)} with the following error: #{inspect({error})}
            """)
        end

        # Return :ok if the cleanup does not fully succeeds
        {:ok, tenant}
      end
    end)
  end

  defp cleanup_system_models(system_model_ids, tenant) do
    system_model_ids |> IO.inspect() |> Logger.debug("Cleaning up SystemModels with IDs:")

    Enum.each(system_model_ids, fn system_model_id ->
      case Ash.get(SystemModel, system_model_id, tenant: tenant, load: [:tenant]) do
        {:ok, system_model} ->
          case Devices.delete_system_model(system_model, tenant: tenant) do
            {:ok, _} ->
              :ok

            {:error, %Ash.Error.Changes.StaleRecord{}} ->
              Logger.warning("SystemModel #{system_model_id} already deleted, skipping...")

            {:error, reason} ->
              Logger.error("Failed to delete SystemModel #{system_model_id}: #{inspect(reason)}")
          end

        {:error, %Ash.Error.Query.NotFound{}} ->
          Logger.warning("SystemModel #{system_model_id} not found, skipping...")

        {:error, reason} ->
          Logger.error("Failed to fetch SystemModel #{system_model_id}: #{inspect(reason)}")
      end
    end)
  end

  defp cleanup_base_images(base_image_ids, tenant) do
    for image_id <- base_image_ids do
      case Ash.get(BaseImage, image_id, tenant: tenant) do
        {:ok, image} ->
          BaseImages.delete_base_image!(image, tenant: tenant)

        _ ->
          :ok
      end
    end
  end

  defp cleanup_ephimeral_images(ota_ids, tenant) do
    for ota_id <- ota_ids do
      case Ash.get(OTAOperation, ota_id, tenant: tenant) do
        {:ok, ota} ->
          OSManagement.delete_ota_operation!(ota, tenant: tenant)

        _ ->
          :ok
      end
    end
  end
end
