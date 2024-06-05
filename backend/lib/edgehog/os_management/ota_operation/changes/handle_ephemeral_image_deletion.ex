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

defmodule Edgehog.OSManagement.OTAOperation.Changes.HandleEphemeralImageDeletion do
  use Ash.Resource.Change

  alias Edgehog.OSManagement.EphemeralImage

  @ephemeral_image_module Application.compile_env(
                            :edgehog,
                            :os_management_ephemeral_image_module,
                            EphemeralImage
                          )

  @impl true
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, &cleanup_base_image_url/2)
  end

  defp cleanup_base_image_url(changeset, {:ok, ota_operation} = result) do
    tenant_id = changeset.to_tenant

    # We do our best to clean up
    _ = @ephemeral_image_module.delete(tenant_id, ota_operation.id, ota_operation.base_image_url)

    result
  end

  defp cleanup_base_image_url(_changeset, result) do
    result
  end
end
