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

  defp maybe_add_operations(dsl_state, operations, {obj_type, obj_id_attr} = _obj_info)
       when is_list(operations) do
    # TODO
    dsl_state
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

  #
  # @impl true
  # def after?(Ash.Policy.Authorizer), do: false
  # def after?(_), do: true
  #
  # @impl true
  # def before?(Ash.Policy.Authorizer), do: true
  # def before?(_), do: false
end
