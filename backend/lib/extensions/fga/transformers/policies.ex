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

defmodule Ash.FGA.Transformers.Policies do
  @moduledoc """
  An Ash extension transformer that adds Edgehog `Filter` policy to reads and `Check` policy
  to creates, updates and deletes.
  """

  use Spark.Dsl.Transformer

  alias Ash.FGA.Info
  alias Ash.Policy.Check.Builtins
  alias Edgehog.Auth.Policies
  alias Spark.Dsl.Transformer

  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    can_view? = Info.can_view?(dsl_state)
    can_edit? = Info.can_edit?(dsl_state)
    can_delete? = Info.can_delete?(dsl_state)
    operations = Info.operations(dsl_state)

    obj_info = {Info.type(dsl_state), Info.id(dsl_state)}

    dsl_state =
      dsl_state
      |> maybe_add_can_view(can_view?, obj_info)
      |> maybe_add_can_edit(can_edit?, obj_info)
      |> maybe_add_can_delete(can_delete?, obj_info)
      |> maybe_add_operations(operations, obj_info)

    # |> add_fallback()

    {:ok, dsl_state}
  end

  defp maybe_add_can_view(dsl_state, true, {obj_type, obj_id_attr} = _obj_info) do
    policy_check = {Policies.Filter, rel: :can_view, obj: obj_type, obj_id: obj_id_attr}
    condition = Builtins.action_type(:create)

    add_policy(dsl_state, policy_check, condition)
  end

  defp maybe_add_can_view(dsl_state, false, _obj_info), do: dsl_state

  defp maybe_add_can_edit(dsl_state, true, {obj_type, obj_id_attr} = _obj_info) do
    policy_check = {Policies.Check, rel: :can_edit, obj: obj_type, obj_id: obj_id_attr}
    condition = Builtins.action_type(:update)

    add_policy(dsl_state, policy_check, condition)
  end

  defp maybe_add_can_edit(dsl_state, false, _obj_info), do: dsl_state

  defp maybe_add_can_delete(dsl_state, true, {obj_type, obj_id_attr} = _obj_info) do
    policy_check = {Policies.Check, rel: :can_delete, obj: obj_type, obj_id: obj_id_attr}
    condition = Builtins.action_type(:destroy)

    add_policy(dsl_state, policy_check, condition)
  end

  defp maybe_add_can_delete(dsl_state, false, _obj_info), do: dsl_state

  defp maybe_add_operations(dsl_state, operations, obj_info)
       when is_list(operations) do
    # if obj_type == :release do
    #   operations |> hd() |> is_tuple() |> dbg()
    # else
    #   dbg({obj_type, operations})
    # end

    operations
    |> Enum.flat_map(&make_operation_tuple/1)
    |> Enum.map(&make_policy_check_and_conditions(&1, obj_info))
    |> Enum.unzip()
    |> Tuple.to_list()
    |> Enum.zip_reduce(dsl_state, fn [policy_check, condition], dsl_state ->
      add_policy(dsl_state, policy_check, condition)
    end)
  end

  defp maybe_add_operations(dsl_state, [], _obj_info), do: dsl_state

  defp add_policy(dsl_state, policy_check, condition) do
    {:ok, check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:policies, :policy],
        :authorize_if,
        check: policy_check
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :policy,
        condition: [condition],
        policies: [check]
      )

    Transformer.add_entity(dsl_state, [:policies], policy, type: :prepend)
  end

  defp make_operation_tuple(op) when is_atom(op),
    do: make_operation_tuple({op, :update})

  defp make_operation_tuple({op_name, op_actions}) when is_list(op_actions) do
    Enum.map(op_actions, &{op_name, &1})
  end

  defp make_operation_tuple({_, _} = op), do: [op]

  defp make_policy_check_and_conditions(
         {op_name, op_action} = _operation,
         {obj_type, obj_id_attr} = _obj_info
       ) do
    rel =
      if op_name |> Atom.to_string() |> String.starts_with?("can_") do
        op_name
      else
        # This code is run at compile time and there is a small set of operations in the model,
        # so no worries of having too many atoms created.
        # Also, it's likely the atoms don't exist, and we don't want it to raise
        # credo:disable-for-next-line
        String.to_atom("can_#{Atom.to_string(op_name)}")
      end

    policy_check = {Policies.Check, rel: rel, obj: obj_type, obj_id: obj_id_attr}

    condition =
      if op_action in [:create, :read, :update, :destroy] do
        Builtins.action_type(op_action)
      else
        op_action
        |> Atom.to_string()
        |> case do
          # This convention is used when an action is named as an action type, hence the atom is existing
          "named_" <> op_action -> String.to_existing_atom(op_action)
          _ -> op_action
        end
        |> Builtins.action()
      end

    {policy_check, condition}
  end
end
