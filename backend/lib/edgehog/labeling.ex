#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Labeling do
  @moduledoc """
  The Labeling context, containing all functionalities regarding tags and attributes assignment
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Edgehog.Labeling.{DeviceTag, Tag}
  alias Edgehog.Repo

  @doc """
  Inserts the tags passed in attrs within a multi transaction, normalizing them.

  Returns the updated `%Ecto.Multi{}`.
  """
  def ensure_tags_exist_multi(multi, %{tags: _tags} = attrs) do
    multi
    |> Multi.run(:cast_tags, fn _repo, _changes ->
      data = %{}
      types = %{tags: {:array, :string}}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(attrs, Map.keys(types))

      with {:ok, %{tags: tags}} <- Ecto.Changeset.apply_action(changeset, :insert) do
        tenant_id = Repo.get_tenant_id()

        now =
          NaiveDateTime.utc_now()
          |> NaiveDateTime.truncate(:second)

        tag_maps =
          for tag <- tags,
              tag = normalize_tag(tag),
              tag != "" do
            %{name: tag, inserted_at: now, updated_at: now, tenant_id: tenant_id}
          end

        {:ok, tag_maps}
      end
    end)
    |> Multi.insert_all(:insert_tags, Tag, & &1.cast_tags, on_conflict: :nothing)
    |> Multi.run(:ensure_tags_exist, fn repo, %{cast_tags: tag_maps} ->
      tag_names = for t <- tag_maps, do: t.name
      {:ok, repo.all(from t in Tag, where: t.name in ^tag_names)}
    end)
  end

  def ensure_tags_exist_multi(multi, _attrs) do
    # No tags in the update, so we return nil for tags
    Multi.run(multi, :ensure_tags_exist, fn _repo, _previous ->
      {:ok, nil}
    end)
  end

  @doc """
  Returns the list of device tags.

  ## Examples

      iex> list_device_tags()
      [%Tag{}, ...]

  """
  def list_device_tags do
    query =
      from t in Tag,
        join: dt in DeviceTag,
        on: t.id == dt.tag_id

    Repo.all(query)
  end

  defp normalize_tag(tag) do
    tag
    |> String.trim()
    |> String.downcase()
  end
end
