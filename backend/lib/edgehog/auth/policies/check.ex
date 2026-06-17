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

defmodule Edgehog.Auth.Policies.Check do
  @moduledoc """
  An `Ash.Policy.SimpleCheck`, checking the user `subj` has access to the object of type `obj`.
  You can optionally pass the `obj_id` attribute name.

  To use it in a policy:
  ```elixir
  authorize_if {Edgehog.Auth.Policies.Check, rel: :can_view, obj: :realm, obj_id: :name}
  ```
  """

  use Ash.Policy.SimpleCheck

  alias Ash.Policy.SimpleCheck
  alias Edgehog.Auth.FGAService

  @subject_type "user"

  @impl SimpleCheck
  def match?(nil, _context, _opts), do: {:error, :no_actor}

  @impl SimpleCheck
  def match?(actor, authorizer, opts) do
    subj = Map.get(actor, :sub) || "anon"

    rel = opts |> Keyword.fetch!(:rel) |> to_string()
    obj_type = opts |> Keyword.fetch!(:obj) |> to_string()
    obj_id_attr = Keyword.get(opts, :obj_id, :id)

    obj_id =
      case authorizer.subject do
        %Ash.Query{filter: filter} = query ->
          case Ash.Filter.fetch_simple_equality_predicate(filter, obj_id_attr) do
            {:ok, found} ->
              found

            :error ->
              {:ok, res} = Ash.read_one(query, load: obj_id_attr, authorize?: false)
              Map.get(res, obj_id_attr)
          end

        authorizer_subject ->
          Ash.Subject.get_argument_or_attribute(authorizer_subject, obj_id_attr)
      end

    subject = "#{@subject_type}:#{subj}"
    object = "#{obj_type}:#{obj_id}"

    FGAService.check(subject, rel, object)
  end

  @impl Ash.Policy.Check
  def describe(opts) do
    rel = Keyword.fetch!(opts, :rel)
    obj = Keyword.fetch!(opts, :obj)
    "Checking if actor has relation #{inspect(rel)} with objects of type #{inspect(obj)}"
  end
end
