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

defmodule Edgehog.Tenants.Tenant.Changes.HandleCleanup do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.BaseImages
  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.Devices
  alias Edgehog.OSManagement.EphemeralImage
  alias Edgehog.OSManagement.OTAOperation

  require Ash.Query

  @ephemeral_image_module Application.compile_env(
                            :edgehog,
                            :os_management_ephemeral_image_module,
                            EphemeralImage
                          )

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, tenant ->
      try do
        cleanup_system_models(tenant)
        cleanup_base_images(tenant)
        cleanup_ephimeral_images(tenant)
        {:ok, tenant}
      rescue
        e -> {:error, e}
      end
    end)
  end

  defp cleanup_base_images(tenant) do
    base_images =
      BaseImage
      |> Ash.Query.filter(tenant_id == ^tenant.tenant_id)
      |> Ash.read!(tenant: tenant)

    for image <- base_images do
      BaseImages.delete_base_image!(image, tenant: tenant)
    end
  end

  defp cleanup_ephimeral_images(tenant) do
    manual_otas =
      OTAOperation
      |> Ash.Query.filter(tenant_id == ^tenant.tenant_id)
      |> Ash.Query.filter(manual?)
      |> Ash.read!(tenant: tenant)

    for ota <- manual_otas do
      # we do our best to cleanup
      _ = @ephemeral_image_module.delete(tenant.tenant_id, ota.id, ota.base_image_url)
    end
  end

  defp cleanup_system_models(tenant) do
    system_models =
      Edgehog.Devices.SystemModel
      |> Ash.Query.filter(tenant_id == ^tenant.tenant_id)
      |> Ash.read!(tenant: tenant)

    for system_model <- system_models do
      Devices.delete_system_model!(system_model, tenant: tenant)
    end
  end
end
