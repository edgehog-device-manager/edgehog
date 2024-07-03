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

defmodule Edgehog.Devices.SystemModel.Changes.HandlePictureDeletion do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Assets
  alias Edgehog.Devices.SystemModel

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, opts, _context) do
    current_picture_url = Ash.Changeset.get_data(changeset, :picture_url)

    delete? = changing_picture?(changeset) or opts[:force?]

    if current_picture_url != nil and delete? do
      Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
        maybe_delete_old_picture(result, current_picture_url, opts[:force?])
      end)
    else
      changeset
    end
  end

  defp changing_picture?(changeset) do
    with :error <- Ash.Changeset.fetch_argument(changeset, :picture_file),
         :error <- Ash.Changeset.fetch_change(changeset, :picture_url) do
      false
    else
      # Note that here we return true even if one of those returns `{:ok, nil}`
      # In that case the user is _unsetting_ the picture, so we still have to delete
      # the existing one
      _ -> true
    end
  end

  # If force? is true and the transaction was a success, we delete the picture
  defp maybe_delete_old_picture({:ok, system_model} = result, old_picture_url, true) do
    _ = Assets.delete_system_model_picture(system_model, old_picture_url)

    result
  end

  # Otherwise, we explicitly delete the old picture only if it had a different URL. If the URL
  # is the same, the old picture just gets overwritten by the new one
  defp maybe_delete_old_picture({:ok, %SystemModel{picture_url: new_picture_url}} = result, old_picture_url, _force?)
       when old_picture_url != new_picture_url do
    {:ok, system_model} = result
    _ = Assets.delete_system_model_picture(system_model, old_picture_url)

    result
  end

  defp maybe_delete_old_picture(result, _old_picture_url, _force), do: result
end
