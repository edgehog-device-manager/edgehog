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

  alias Edgehog.Assets
  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.BaseImages.BucketStorage
  alias Edgehog.Devices.SystemModel
  alias Edgehog.OSManagement.EphemeralImage
  alias Edgehog.OSManagement.OTAOperation

  require Ash.Query
  require Logger

  @ephemeral_image_module Application.compile_env(
                            :edgehog,
                            :os_management_ephemeral_image_module,
                            EphemeralImage
                          )

  @storage_module Application.compile_env(
                    :edgehog,
                    :base_images_storage_module,
                    BucketStorage
                  )

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    tenant = changeset.data

    system_models =
      Ash.read!(SystemModel, tenant: tenant)

    base_images =
      Ash.read!(BaseImage, tenant: tenant)

    manual_otas =
      OTAOperation
      |> Ash.Query.filter(manual?)
      |> Ash.read!(tenant: tenant)

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, tenant} <- result do
        try do
          cleanup_system_models(system_models)
          cleanup_base_images(base_images)
          cleanup_ephimeral_images(manual_otas, tenant.tenant_id)
        catch
          signal, error ->
            Logger.error("""
            Tenant cleanup was not completed:
            received signal #{inspect(signal)} with the following error: #{inspect({error})}
            """)
        end

        {:ok, tenant}
      end
    end)
  end

  defp cleanup_system_models(system_models) do
    Enum.each(system_models, fn system_model ->
      current_picture_url = system_model.picture_url

      if current_picture_url != nil do
        maybe_delete_old_picture(system_model, current_picture_url, true)
      end
    end)
  end

  defp cleanup_base_images(base_images) do
    Enum.each(base_images, fn base_image ->
      delete_old_file(base_image)
    end)
  end

  defp cleanup_ephimeral_images(ota_ids, tenant_id) do
    Enum.each(ota_ids, fn ota_operation ->
      _ =
        @ephemeral_image_module.delete(tenant_id, ota_operation.id, ota_operation.base_image_url)
    end)
  end

  defp maybe_delete_old_picture(system_model, old_picture_url, true) do
    _ = Assets.delete_system_model_picture(system_model, old_picture_url)
  end

  defp delete_old_file(base_image) do
    _ = @storage_module.delete(base_image)
  end
end
