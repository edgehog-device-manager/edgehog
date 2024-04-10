#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Selector.AST.TagFilter do
  defstruct [:tag, :operator]

  @type t :: %__MODULE__{
          tag: String.t(),
          operator: :in | :not_in
        }

  import Ecto.Query
  alias Edgehog.Labeling
  alias Edgehog.Selector.AST.TagFilter
  require Ash.Query

  @doc """
  Converts a `%TagFilter{}` to a dynamic where clause filtering `Astarte.Device`s that match the
  given `%TagFilter{}`.

  Returns `{:ok, dynamic_query}` or `{:error, %Parser.Error{}}`
  """
  def to_ecto_dynamic_query(%TagFilter{tag: tag, operator: operator})
      when operator in [:in, :not_in] and is_binary(tag) do
    query = Labeling.DeviceTag.device_ids_matching_tag(tag)

    dynamic =
      case operator do
        :in ->
          dynamic([d], d.id in subquery(query))

        :not_in ->
          dynamic([d], d.id not in subquery(query))
      end

    {:ok, dynamic}
  end

  defimpl Edgehog.Selector.Filter do
    def to_ash_expr(tag_filter) do
      tag_name = tag_filter.tag

      case tag_filter.operator do
        :in -> Ash.Query.expr(exists(tags, name == ^tag_name))
        :not_in -> Ash.Query.expr(not exists(tags, name == ^tag_name))
      end
    end
  end
end
