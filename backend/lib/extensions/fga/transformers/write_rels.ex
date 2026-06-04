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

defmodule Ash.FGA.Transformers.WriteRels do
  @moduledoc """
  An Ash extension transformer that adds changes to write and delete FGA tuples based on a resource's relationships

  Flow:
  - collects the `belongs_to` relationships
  - filters the `excluded` relationships
  - for each relationship, adds the changes that write/delete the correct tuple in the FGA service
  """

  use Spark.Dsl.Transformer

  alias Ash.FGA.Info
  alias Ash.Resource.Builder
  alias Ash.Resource.Relationships.BelongsTo
  alias Edgehog.Auth.Changes

  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    exclusions =
      dsl_state
      |> Info.exclude()
      |> Enum.map(& &1.relationships)
      |> List.flatten()

    dsl_state
    |> Ash.Resource.Info.relationships()
    |> Enum.filter(&valid?(&1, exclusions))
    |> Enum.reduce({:ok, dsl_state}, &add_change/2)
  end

  defp valid?(%BelongsTo{name: rel}, exclusions),
    do: rel not in exclusions

  defp valid?(_, _), do: false

  defp add_change(rel, {:ok, dsl_state}) do
    do_add_change(rel, dsl_state)
  end

  defp add_change(rel, {:warn, dsl_state, warnings}) do
    case do_add_change(rel, dsl_state) do
      {:ok, dsl_state} -> {:warn, dsl_state, warnings}
      {:warn, dsl_state, new_warnings} -> {:warn, dsl_state, new_warnings ++ warnings}
    end
  end

  defp do_add_change(
         %BelongsTo{name: rel, destination: dest},
         dsl_state
       ) do
    source_type = Info.type(dsl_state)
    source_id = Info.id(dsl_state)

    dest_id = Info.id(dest)
    dest_type = Info.type(dest)

    write_change = {
      Changes.WriteRelation,
      relationship: rel,
      destination_type: dest_type,
      destination_id: dest_id,
      source_type: source_type,
      source_id: source_id
    }

    erase_change = {
      Changes.EraseRelation,
      relationship: rel,
      destination_type: dest_type,
      destination_id: dest_id,
      source_type: source_type,
      source_id: source_id
    }

    warn_message = """
    Resource #{inspect(dest)} does not contain an `fga` annotation.

    its type is `nil`, which means that either the `Ash.FGA` extension was not added to the resource or that no `type` option was provided.

    your tests will probably fail !
    """

    with {:ok, dsl_state} <-
           Builder.add_change(dsl_state, write_change, on: [:create]),
         {:ok, dsl_state} <-
           Builder.add_change(dsl_state, erase_change, on: [:destroy]) do
      if dest_type,
        do: {:ok, dsl_state},
        else: {:warn, dsl_state, [warn_message]}
    end
  end
end
