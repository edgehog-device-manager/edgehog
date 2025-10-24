#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Calculations.Dangling do
  @moduledoc """
  Is the current resource dangling? Meaning, is it related to other entities?
  """

  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @parent_key :parent

  @impl Calculation
  def init(opts) do
    if Keyword.has_key?(opts, @parent_key) do
      {:ok, opts}
    else
      {:error, :missing_parent_key}
    end
  end

  @impl Calculation
  def load(_query, opts, _context) do
    opts[@parent_key]
  end

  @impl Calculation
  def calculate(records, opts, _context) do
    parent = Keyword.fetch!(opts, @parent_key)
    Enum.map(records, &dangling?(&1, parent))
  end

  def dangling?(resource, parent) do
    case Map.get(resource, parent) do
      nil -> true
      [] -> true
      _ -> false
    end
  end
end
