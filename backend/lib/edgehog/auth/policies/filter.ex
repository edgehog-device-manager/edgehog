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

defmodule Edgehog.Auth.Policies.Filter do
  @moduledoc """
  An `Ash.Policy.FilterCheck`, filtering the object of type `obj` available to the user `subj`.

  To use it in a policy:
  ```elixir
  filter_by {Edgehog.Auth.Policies.Filter, rel: :can_view, obj: :device}
  ```
  """

  use Ash.Policy.FilterCheck

  alias Ash.Policy.FilterCheck
  alias Edgehog.Auth.FGAService

  require Logger

  @impl FilterCheck
  def filter(actor, _context, opts) do
    subj = actor.sub

    rel = opts |> Keyword.fetch!(:rel) |> to_string()
    obj_type = opts |> Keyword.fetch!(:obj) |> to_string()
    obj_id = Keyword.get(opts, :obj_id, :id)

    log_context = [
      subj: subj,
      obj_type: obj_type,
      obj_id: obj_id
    ]

    subj
    |> FGAService.list_objects(rel, obj_type)
    |> to_ash_expr(obj_id, log_context)
  end

  @impl FilterCheck
  def reject(actor, _context, opts) do
    subj = actor.sub

    rel = opts |> Keyword.fetch!(:rel) |> to_string()
    obj_type = opts |> Keyword.fetch!(:obj) |> to_string()
    obj_id = Keyword.get(opts, :obj_id, :id)

    log_context = [
      subj: subj,
      obj_type: obj_type,
      obj_id: obj_id
    ]

    subj
    |> FGAService.list_objects(rel, obj_type)
    |> to_ash_expr(obj_id, log_context)
  end

  @impl Ash.Policy.Check
  def describe(opts) do
    rel = Keyword.fetch!(opts, :rel)
    obj = Keyword.fetch!(opts, :obj)
    "Filtering objects of type #{inspect(obj)} where actor has relation #{inspect(rel)}"
  end

  defp to_ash_expr({:ok, ids}, id_attribute, _log_context), do: expr(^ref(id_attribute) in ^ids)

  defp to_ash_expr({:error, error}, _id_attribute, log_context) do
    Logger.error("Error while filtering: #{inspect(error)}", log_context)

    # We had an error while interrogating the provider. Poison everything.
    expr(nil)
  end
end
