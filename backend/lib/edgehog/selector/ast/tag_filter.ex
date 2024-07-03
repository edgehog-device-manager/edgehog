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

defmodule Edgehog.Selector.AST.TagFilter do
  import Ash.Expr

  @type t :: %__MODULE__{
          tag: String.t(),
          operator: :in | :not_in
        }

  defstruct [:tag, :operator]

  defimpl Edgehog.Selector.Filter do
    def to_ash_expr(tag_filter) do
      tag_name = tag_filter.tag

      case tag_filter.operator do
        :in -> expr(exists(tags, name == ^tag_name))
        :not_in -> expr(not exists(tags, name == ^tag_name))
      end
    end
  end
end
