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

defmodule Edgehog.Localization.Calculations.LocalizedAttributes do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @impl Calculation
  def init(opts) do
    if opts[:attribute] && is_atom(opts[:attribute]) do
      {:ok, opts}
    else
      {:error, "Expected an `attribute` option"}
    end
  end

  @impl Calculation
  def load(_query, opts, _context) do
    List.wrap(opts[:attribute])
  end

  @impl Calculation
  def calculate(records, opts, context) do
    language_select_fun =
      case Map.fetch(context.arguments, :preferred_language_tags) do
        {:ok, preferred} when is_list(preferred) ->
          &Map.take(&1, preferred)

        _ ->
          &Function.identity/1
      end

    Enum.map(records, fn record ->
      attribute_map = Map.fetch!(record, opts[:attribute]) || %{}

      attribute_map
      |> language_select_fun.()
      |> Enum.map(fn {language_tag, value} ->
        %{language_tag: language_tag, value: value}
      end)
    end)
  end
end
