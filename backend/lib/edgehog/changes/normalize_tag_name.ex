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

defmodule Edgehog.Changes.NormalizeTagName do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Resource.Change

  @impl Change
  def init(opts) do
    attribute = opts[:attribute]
    argument = opts[:argument]

    ok? =
      case {attribute, argument} do
        {nil, nil} -> false
        {attribute, argument} when attribute != nil and argument != nil -> false
        _ -> true
      end

    if ok? do
      {:ok, opts}
    else
      {:error, "You must provide either `attribute: :attribute_name` or `argument: :argument_name`."}
    end
  end

  @impl Change
  def change(changeset, opts, _ctx) do
    case fetch_tag(changeset, opts) do
      {:ok, name} when is_binary(name) ->
        normalized_name = normalize(name)
        set_tag(changeset, opts, normalized_name)

      {:ok, names} when is_list(names) ->
        normalized_names = Enum.map(names, &normalize/1)
        set_tag(changeset, opts, normalized_names)

      _ ->
        changeset
    end
  end

  defp fetch_tag(changeset, opts) do
    cond do
      opts[:attribute] -> Ash.Changeset.fetch_change(changeset, opts[:attribute])
      opts[:argument] -> Ash.Changeset.fetch_argument(changeset, opts[:argument])
    end
  end

  defp set_tag(changeset, opts, normalized) do
    cond do
      opts[:attribute] -> Ash.Changeset.change_attribute(changeset, opts[:attribute], normalized)
      opts[:argument] -> Ash.Changeset.set_argument(changeset, opts[:argument], normalized)
    end
  end

  defp normalize(nil), do: nil

  defp normalize(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
  end
end
