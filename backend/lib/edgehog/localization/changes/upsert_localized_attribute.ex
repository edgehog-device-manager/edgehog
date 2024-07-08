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

defmodule Edgehog.Localization.Changes.UpsertLocalizedAttribute do
  @moduledoc """
  Creates a localized attribute.
  """

  use Ash.Resource.Change

  def init(opts) do
    cond do
      !opts[:target_attribute] or not is_atom(opts[:target_attribute]) ->
        {:error, "target_attribute must be an atom"}

      !opts[:input_argument] or not is_atom(opts[:input_argument]) ->
        {:error, "input_argument must be an atom"}

      true ->
        {:ok, opts}
    end
  end

  def change(changeset, opts, _context) do
    argument = opts[:input_argument]
    attribute = opts[:target_attribute]
    current_attribute_value = Map.fetch!(changeset.data, attribute) || %{}

    case Ash.Changeset.fetch_argument(changeset, argument) do
      {:ok, values} when is_list(values) ->
        {updates, deletions} =
          Enum.split_with(values, &(&1.value != nil))

        attribute_update_map =
          Map.new(updates, fn %{language_tag: language_tag, value: value} ->
            {language_tag, value}
          end)

        to_be_deleted = Enum.map(deletions, & &1.language_tag)

        attribute_map =
          current_attribute_value
          |> Map.drop(to_be_deleted)
          |> Map.merge(attribute_update_map)

        Ash.Changeset.change_attribute(changeset, attribute, attribute_map)

      _ ->
        changeset
    end
  end
end
