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

defmodule Edgehog.BaseImages.BaseImage.Changes.HandleFileUpload do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.BaseImages.BucketStorage

  @storage_module Application.compile_env(
                    :edgehog,
                    :base_images_storage_module,
                    BucketStorage
                  )

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :file) do
      {:ok, %Plug.Upload{} = file} ->
        changeset
        |> Ash.Changeset.before_transaction(&upload_file(&1, file))
        |> Ash.Changeset.after_transaction(&cleanup_on_error(&1, &2))

      _ ->
        changeset
    end
  end

  defp upload_file(changeset, file) do
    tenant_id = changeset.to_tenant

    {:ok, base_image_version} = Ash.Changeset.fetch_change(changeset, :version)

    {:ok, base_image_collection_id} =
      Ash.Changeset.fetch_argument(changeset, :base_image_collection_id)

    case @storage_module.store(tenant_id, base_image_collection_id, base_image_version, file) do
      {:ok, file_url} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:url, file_url)
        |> Ash.Changeset.put_context(:file_uploaded?, true)

      {:error, _reason} ->
        Ash.Changeset.add_error(changeset, field: :file, message: "failed to upload")
    end
  end

  # If we've uploaded the file and the transaction resulted in an error, we do our
  # best to clean up
  defp cleanup_on_error(changeset, {:error, _} = result) do
    if changeset.context[:file_uploaded?] do
      {:ok, base_image} = Ash.Changeset.apply_attributes(changeset)
      _ = @storage_module.delete(base_image)
    end

    result
  end

  defp cleanup_on_error(_changeset, result), do: result
end
