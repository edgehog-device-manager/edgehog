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

    system_models = Ash.read!(SystemModel, tenant: tenant)

    base_images = Ash.read!(BaseImage, tenant: tenant)

    manual_otas =
      OTAOperation
      |> Ash.Query.filter(manual?)
      |> Ash.read!(tenant: tenant)

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, tenant} <- result do
        try do
          cleanup_system_models(system_models, tenant)
          cleanup_base_images(base_images, tenant)
          cleanup_ephimeral_images(manual_otas, tenant)
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

  defp cleanup_system_models(system_models, tenant) do
    for system_model <- system_models do
      Devices.delete_system_model!(system_model, tenant: tenant)
    end
  end

  defp cleanup_base_images(base_images, tenant) do
    for image <- base_images do
      BaseImages.delete_base_image!(image, tenant: tenant)
    end
  end

  defp cleanup_ephimeral_images(manual_otas, tenant) do
    for ota <- manual_otas do
      OSManagement.delete_ota_operation!(ota, tenant: tenant)
    end
  end
end
