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

defmodule Ash.Audit.Transformers.ResolveConfiguration do
  @moduledoc """
  An Ash Audit extension transformer that resolves the provided configuration and produces
  the list of audited actions.

  Flow:
  - computes actions belonging to the `included_action_types` on the resource and
     merges them with the `included_actions`; if only one of the two is defined,
     the other (defaulting to all) is ignored
  - computes actions belonging to the `excluded_action_types` on the resource and
    merges them with the `excluded_actions`
  - subtracts the list of excluded actions from the list of included ones
  """

  use Spark.Dsl.Transformer

  alias Ash.Audit.Info
  alias Spark.Dsl.Transformer

  @default_action_types [:create, :update, :destroy]
  @valid_action_types @default_action_types ++ [:action]
  @types_sentinel :audit_all_action_types
  @actions_sentinel :audit_all_actions

  @impl Spark.Dsl.Transformer
  def after?(Ash.Resource.Transformers.DefaultAccept), do: true
  def after?(Ash.Resource.Transformers.SetPrimaryActions), do: true
  def after?(_other), do: false

  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    included_action_types = Info.included_action_types(dsl_state)
    included_actions = Info.included_actions(dsl_state)
    resolved_included = resolve(dsl_state, included_action_types, included_actions)

    excluded_action_types = Info.excluded_action_types(dsl_state)
    excluded_actions = Info.excluded_actions(dsl_state)
    resolved_excluded = resolve(dsl_state, excluded_action_types, excluded_actions)

    resolved = Enum.reject(resolved_included, fn action -> action in resolved_excluded end)

    dsl_state
    |> Transformer.persist(:resolved_audited_actions, resolved)
    |> then(&{:ok, &1})
  end

  defp resolve(dsl_state, [@types_sentinel], [@actions_sentinel]),
    do: resolve_actions_of_types(dsl_state, @default_action_types)

  defp resolve(dsl_state, [@types_sentinel], actions),
    do: dsl_state |> resolve_actions(actions) |> Enum.uniq()

  defp resolve(dsl_state, action_types, [@actions_sentinel]),
    do: resolve_actions_of_types(dsl_state, action_types)

  defp resolve(dsl_state, action_types, actions),
    do:
      Enum.uniq(
        resolve_actions_of_types(dsl_state, action_types) ++ resolve_actions(dsl_state, actions)
      )

  defp resolve_actions_of_types(dsl_state, types) do
    case Enum.reject(types, &(&1 in @valid_action_types)) do
      [] ->
        dsl_state
        |> Ash.Resource.Info.actions()
        |> Enum.filter(fn action -> action.type in types end)

      unknown ->
        raise Spark.Error.DslError,
          path: [:audit_log],
          message:
            "unsupported action types #{inspect(unknown)}, expected one of #{inspect(@valid_action_types)}"
    end
  end

  defp resolve_actions(dsl_state, actions) do
    Enum.reduce(actions, [], &validate_action_exists(dsl_state, &1, &2))
  end

  defp validate_action_exists(dsl_state, action, validated) do
    case Ash.Resource.Info.action(dsl_state, action) do
      nil ->
        raise Spark.Error.DslError,
          path: [:audit_log],
          message: "no action named #{inspect(action)} on this resource"

      %{type: action_type} when action_type not in @valid_action_types ->
        raise Spark.Error.DslError,
          path: [:audit_log],
          message:
            "unsupported type #{inspect(action_type)} for action #{inspect(action)} on this resource"

      action ->
        [action | validated]
    end
  end
end
