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

defmodule Ash.Audit.Transformers.ApplyConfiguration do
  @moduledoc """
  An Ash Audit extension transformer that applies audit hooks to the actions
  resolved by `Ash.Audit.Transformers.ResolveConfiguration`.

  Create/update/destroy actions get an audit change attached
  (`Edgehog.Audit.Changes.RegisterEvent`), while manual actions get an
  audit preparation attached (`Edgehog.Audit.Preparations.RegisterEvent`): read
  and manual actions do not support `Ash.Resource.Change`s, but only
  `Ash.Resource.Preparation`s.
  """

  use Spark.Dsl.Transformer

  alias Ash.Audit.Info
  alias Ash.Resource.Builder
  alias Edgehog.Audit.Changes
  alias Edgehog.Audit.Preparations
  alias Spark.Dsl.Transformer

  @change_action_types [:create, :update, :destroy]
  @preparation_action_types [:action]

  @impl Spark.Dsl.Transformer
  def after?(Ash.Audit.Transformers.ResolveConfiguration), do: true
  def after?(_other), do: false

  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    resolved_actions = Transformer.get_persisted(dsl_state, :resolved_audited_actions)
    opts = [actor?: Info.actor?(dsl_state)]

    dsl_state =
      Enum.reduce(resolved_actions, dsl_state, fn action, dsl_state ->
        case action.type do
          type when type in @change_action_types ->
            add_audit_change(dsl_state, action, opts)

          type when type in @preparation_action_types ->
            add_audit_preparation(dsl_state, action, opts)
        end
      end)

    {:ok, dsl_state}
  end

  defp add_audit_change(dsl_state, %{name: name, type: type} = action, opts) do
    {:ok, audit_entity} = Builder.build_action_change({Changes.RegisterEvent, opts})

    updated_action = Map.update!(action, :changes, &[audit_entity | &1])
    replace_action(dsl_state, updated_action, name, type)
  end

  defp add_audit_preparation(dsl_state, %{name: name, type: type} = action, opts) do
    {:ok, audit_entity} =
      Transformer.build_entity(
        Ash.Resource.Dsl,
        [:actions, type],
        :prepare,
        preparation: {Preparations.RegisterEvent, opts}
      )

    updated_action = Map.update!(action, :preparations, &(&1 ++ [audit_entity]))

    replace_action(dsl_state, updated_action, name, type)
  end

  defp replace_action(dsl_state, updated_action, name, type) do
    Transformer.replace_entity(
      dsl_state,
      [:actions],
      updated_action,
      &(&1.name == name && &1.type == type)
    )
  end
end
