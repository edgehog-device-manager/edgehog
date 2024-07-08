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

defmodule Edgehog.Devices.SystemModel.Changes.HandlePictureUpload do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Assets

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :picture_file) do
      {:ok, %Plug.Upload{} = picture_file} ->
        changeset
        |> Ash.Changeset.before_transaction(&upload_picture(&1, picture_file))
        |> Ash.Changeset.after_transaction(&cleanup_on_error(&1, &2))

      _ ->
        changeset
    end
  end

  defp upload_picture(changeset, picture_file) do
    {:ok, system_model} = Ash.Changeset.apply_attributes(changeset)

    case Assets.upload_system_model_picture(system_model, picture_file) do
      {:ok, picture_url} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:picture_url, picture_url)
        |> Ash.Changeset.put_context(:picture_uploaded?, true)

      {:error, _reason} ->
        Ash.Changeset.add_error(changeset, field: :picture_file, message: "failed to upload")
    end
  end

  # If we've uploaded the picture and the transaction resulted in an error, we do our
  # best to clean up
  defp cleanup_on_error(changeset, {:error, _} = result) do
    if changeset.context[:picture_uploaded?] do
      {:ok, %{picture_url: picture_url} = system_model} =
        Ash.Changeset.apply_attributes(changeset)

      _ = Assets.delete_system_model_picture(system_model, picture_url)
    end

    result
  end

  defp cleanup_on_error(_changeset, result), do: result
end
