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

defmodule Edgehog.Devices.Selector do
  alias Edgehog.Devices
  alias Edgehog.Devices.Selector.AST.AttributeFilter
  alias Edgehog.Devices.Selector.AST.BinaryOp
  alias Edgehog.Devices.Selector.AST.TagFilter
  alias Edgehog.Devices.Selector.Parser
  alias Edgehog.Devices.Selector.Parser.Error

  import Ecto.Query

  @doc """
  Translates a selector to an `%Ecto.Query{}` returning all the devices matched by the selector.

  It accepts either a selector in binary form (in which case it first parses it) or its AST.

  Returns `{:ok, %Ecto.Query{}}` or `{:error, %Parser.Error{}}`.
  """
  def to_ecto_query(selector) when is_binary(selector) do
    with {:ok, ast_root} <- parse(selector) do
      to_ecto_query(ast_root)
    end
  end

  def to_ecto_query(%node{} = ast_root)
      when node in [AttributeFilter, BinaryOp, TagFilter] do
    with {:ok, where_condition} <- traverse(ast_root) do
      query =
        from d in Devices.Device,
          where: ^where_condition

      {:ok, query}
    end
  end

  @doc """
  Parses a selector, returning an AST (or an error). The root node can be one of the structs contained in
  the `Edgehog.Devices.Selector.AST` namespace.

  This phase of parsing only checks syntax, semantic analysis takes place when converting the AST to an
  `%Ecto.Query{}`.

  Returns `{:ok, ast_root}` or `{:error, %Parser.Error{}}`.
  """
  def parse(selector) do
    case Parser.parse(selector) do
      {:ok, [ast_root], _rest, _context, _line, _column} ->
        {:ok, ast_root}

      {:error, reason, _rest, _context, {line, _}, column} ->
        {:error, %Error{message: reason, line: line, column: column}}
    end
  end

  # TODO: should we impose a max depth to avoid queries containing lots of subqueries?
  defp traverse(%BinaryOp{operator: operator, lhs: lhs, rhs: rhs}) do
    with {:ok, lhs_condition} <- traverse(lhs),
         {:ok, rhs_condition} <- traverse(rhs) do
      case operator do
        :and ->
          {:ok, dynamic(^lhs_condition and ^rhs_condition)}

        :or ->
          {:ok, dynamic(^lhs_condition or ^rhs_condition)}
      end
    end
  end

  defp traverse(%AttributeFilter{} = attribute_filter) do
    AttributeFilter.to_ecto_dynamic_query(attribute_filter)
  end

  defp traverse(%TagFilter{} = tag_filter) do
    TagFilter.to_ecto_dynamic_query(tag_filter)
  end
end
