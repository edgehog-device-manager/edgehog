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

defmodule Edgehog.Selector.AST.BinaryOp do
  defstruct [:operator, :lhs, :rhs]

  import Ash.Expr

  alias Edgehog.Selector

  defimpl Selector.Filter do
    def to_ash_expr(binary_op) do
      lhs = Selector.Filter.to_ash_expr(binary_op.lhs)
      rhs = Selector.Filter.to_ash_expr(binary_op.rhs)

      case binary_op.operator do
        :and -> expr(^lhs and ^rhs)
        :or -> expr(^lhs or ^rhs)
      end
    end
  end
end
