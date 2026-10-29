#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Containers.Calculations.Hash do
  @moduledoc """
  Computes a deterministic SHA-256 hex hash for a container resource from its
  relevant fields and related resource hashes.
  """

  use Ash.Resource.Calculation

  alias Ash.Query.Calculation, as: QueryCalculation
  alias Ash.Resource.Calculation
  alias Ash.Resource.Info

  @impl Calculation
  def init(opts) do
    fields = Keyword.get(opts, :fields, [])
    relationships = Keyword.get(opts, :relationships, [])

    {:ok, [fields: fields, relationships: relationships]}
  end

  @impl Calculation
  def load(query, opts, _context) do
    fields = Keyword.get(opts, :fields, [])

    relationship_loads =
      opts
      |> Keyword.get(:relationships, [])
      |> Enum.map(fn
        {rel, field} ->
          {rel, [field]}

        rel when is_atom(rel) ->
          relationship = Info.relationship(query.resource, rel)
          {rel, [hash_calculation(relationship.destination, {query.resource, rel})]}
      end)

    fields ++ relationship_loads
  end

  @impl Calculation
  def calculate(records, opts, _context) do
    fields = Keyword.get(opts, :fields, [])
    relationships = Keyword.get(opts, :relationships, [])

    Enum.map(records, &compute_hash(&1, fields, relationships))
  end

  defp compute_hash(record, fields, relationships) do
    field_values = Enum.map(fields, &Map.get(record, &1))
    relationship_values = Enum.map(relationships, &extract_relationship(record, &1))

    :sha256
    |> :crypto.hash(:erlang.term_to_binary({field_values, relationship_values}))
    |> Base.encode16(case: :lower)
  end

  defp extract_relationship(record, {rel, field}) do
    case Map.get(record, rel) do
      nil -> nil
      records when is_list(records) -> records |> Enum.map(&Map.get(&1, field)) |> Enum.sort()
      related -> Map.get(related, field)
    end
  end

  defp extract_relationship(record, rel) when is_atom(rel) do
    extract_relationship(record, {rel, :hash})
  end

  defp hash_calculation(resource, caller) do
    resource_calc = Info.calculation(resource, :hash)

    {:ok, calc} =
      QueryCalculation.from_resource_calculation(resource, resource_calc, args: %{})

    %{
      calc
      | name: {:hash, caller},
        load: :hash,
        calc_name: :hash,
        opts: Keyword.put(calc.opts, :caller, caller)
    }
  end
end
