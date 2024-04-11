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
  use Ash.Resource.Change

  alias Edgehog.BaseImages.BucketStorage

  @storage_module Application.compile_env(
                    :edgehog,
                    :base_images_storage_module,
                    BucketStorage
                  )

  @impl true
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :file) do
      {:ok, %Plug.Upload{} = file} ->
        Ash.Changeset.before_transaction(changeset, &upload_file(&1, file))

      _ ->
        changeset
    end
  end

  defp upload_file(changeset, file) do
    {:ok, base_image} = Ash.Changeset.apply_attributes(changeset)

    case @storage_module.store(base_image, file) do
      {:ok, file_url} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:url, file_url)
        |> Ash.Changeset.after_transaction(&maybe_cleanup(&1, &2))

      {:error, _reason} ->
        Ash.Changeset.add_error(changeset, field: :file, message: "failed to upload")
    end
  end

  # If we've uploaded the file and the transaction resulted in an error, we do our
  # best to clean up
  defp maybe_cleanup(changeset, {:error, _} = result) do
    {:ok, %{url: file_url} = base_image} = Ash.Changeset.apply_attributes(changeset)

    unless is_nil(file_url) do
      _ = @storage_module.delete(base_image)
    end

    result
  end

  defp maybe_cleanup(_changeset, result), do: result
end
