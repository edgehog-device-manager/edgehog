#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule Edgehog.Selector do
  alias Edgehog.Selector.AST.AttributeFilter
  alias Edgehog.Selector.AST.BinaryOp
  alias Edgehog.Selector.AST.TagFilter
  alias Edgehog.Selector.Filter
  alias Edgehog.Selector.Parser
  alias Edgehog.Selector.Parser.Error

  @doc """
  Translates a selector to an `%Ash.Expr{}` matching all devices matched by the selector.

  It accepts the AST root (the Selector must be parsed separately).

  Returns `%Ash.Expr{}`.
  """
  def to_ash_expr(%node{} = ast_root)
      when node in [AttributeFilter, BinaryOp, TagFilter] do
    Filter.to_ash_expr(ast_root)
  end

  @doc """
  Parses a selector, returning an AST (or an error). The root node can be one of the structs contained in
  the `Edgehog.Selector.AST` namespace.

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
end
