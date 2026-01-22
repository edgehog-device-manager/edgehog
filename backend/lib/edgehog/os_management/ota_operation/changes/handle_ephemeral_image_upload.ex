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

defmodule Edgehog.OSManagement.OTAOperation.Changes.HandleEphemeralImageUpload do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.OSManagement.EphemeralImage

  @ephemeral_image_module Application.compile_env(
                            :edgehog,
                            :os_management_ephemeral_image_module,
                            EphemeralImage
                          )

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(%Ash.Changeset{arguments: %{base_image_url: url}} = changeset, _opts, _context),
    do: Ash.Changeset.change_attribute(changeset, :base_image_url, url)

  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :base_image_file) do
      {:ok, %Plug.Upload{} = file} ->
        changeset
        |> Ash.Changeset.before_transaction(&upload_file(&1, file))
        |> Ash.Changeset.after_transaction(&cleanup_on_error(&1, &2))

      _ ->
        changeset
    end
  end

  defp upload_file(changeset, file) do
    # We use to_tenant since that always contains the tenant_id
    tenant_id = changeset.to_tenant
    ota_operation_id = Ash.Changeset.get_attribute(changeset, :id)

    case @ephemeral_image_module.upload(tenant_id, ota_operation_id, file) do
      {:ok, file_url} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:base_image_url, file_url)
        |> Ash.Changeset.put_context(:base_image_uploaded?, true)

      {:error, _reason} ->
        Ash.Changeset.add_error(changeset, field: :base_image_file, message: "failed to upload")
    end
  end

  # If we've uploaded the file and the transaction resulted in an error, we do our
  # best to clean up
  defp cleanup_on_error(changeset, {:error, _} = result) do
    if changeset.context[:base_image_uploaded?] do
      tenant_id = changeset.to_tenant
      ota_operation_id = Ash.Changeset.get_attribute(changeset, :id)
      base_image_url = Ash.Changeset.get_attribute(changeset, :base_image_url)

      _ = @ephemeral_image_module.delete(tenant_id, ota_operation_id, base_image_url)
    end

    result
  end

  defp cleanup_on_error(_changeset, result), do: result
end
