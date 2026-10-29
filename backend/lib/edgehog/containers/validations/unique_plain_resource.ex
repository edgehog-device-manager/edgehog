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

defmodule Edgehog.Containers.Validations.UniquePlainResource do
  @moduledoc """
  Validates that the given attribute keys are unique among plain (un-deployed)
  resources using the specified `read_action`.
  """

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  require Ash.Expr
  require Ash.Query

  @impl Ash.Resource.Validation
  def init(opts) do
    with {:ok, keys} when is_list(keys) and keys != [] <- Keyword.fetch(opts, :keys),
         {:ok, read_action} when is_atom(read_action) <- Keyword.fetch(opts, :read_action),
         {:ok, field} when is_atom(field) <- Keyword.fetch(opts, :field) do
      {:ok, Keyword.put_new(opts, :nils_distinct?, true)}
    else
      _ ->
        {:error, "Expected `:keys`, `:read_action`, and `:field` options"}
    end
  end

  @impl Ash.Resource.Validation
  def validate(changeset, opts, context) do
    if skip_validation?(changeset, opts) do
      :ok
    else
      check_uniqueness(changeset, opts, context.tenant)
    end
  end

  defp skip_validation?(changeset, opts) do
    keys = Keyword.fetch!(opts, :keys)
    nils_distinct? = Keyword.get(opts, :nils_distinct?, true)

    copy? = Map.get(changeset.context, :copy?, false)

    not_changing? =
      changeset.action_type != :create and
        not Enum.any?(keys, &Ash.Changeset.changing_attribute?(changeset, &1))

    has_distinct_nil? =
      nils_distinct? and
        Enum.any?(keys, &(changeset |> Ash.Changeset.get_attribute(&1) |> is_nil()))

    copy? or not_changing? or has_distinct_nil?
  end

  defp check_uniqueness(changeset, opts, tenant) do
    keys = Keyword.fetch!(opts, :keys)
    read_action = Keyword.fetch!(opts, :read_action)
    field = Keyword.fetch!(opts, :field)

    query =
      changeset.resource
      |> Ash.Query.for_read(read_action, %{}, tenant: tenant, authorize?: false)
      |> apply_key_filters(changeset, keys)
      |> maybe_exclude_self(changeset)

    if Ash.exists?(query, tenant: tenant, authorize?: false) do
      {:error, InvalidAttribute.exception(field: field, message: "has already been taken")}
    else
      :ok
    end
  end

  defp apply_key_filters(query, changeset, keys) do
    Enum.reduce(keys, query, fn key, acc_query ->
      case Ash.Changeset.get_attribute(changeset, key) do
        nil ->
          Ash.Query.filter(acc_query, is_nil(^Ash.Expr.ref(key)))

        value ->
          Ash.Query.filter(acc_query, ^Ash.Expr.ref(key) == ^value)
      end
    end)
  end

  defp maybe_exclude_self(query, %{action_type: :update, data: %{id: id}}) do
    Ash.Query.filter(query, id != ^id)
  end

  defp maybe_exclude_self(query, _changeset), do: query
end
