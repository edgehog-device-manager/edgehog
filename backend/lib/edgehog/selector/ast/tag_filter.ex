#
# This file is part of Edgehog.
#
# Copyright 2022 - 2025 SECO Mind Srl
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
  @moduledoc false
  import Ash.Expr

  @type t :: %__MODULE__{
          tag: String.t(),
          operator: :in | :not_in | :matches | :not_matches
        }

  defstruct [:tag, :operator]

  defimpl Edgehog.Selector.Filter do
    def to_ash_expr(tag_filter) do
      tag_pattern = tag_filter.tag

      case tag_filter.operator do
        :in ->
          expr(exists(tags, name == ^tag_pattern))

        :not_in ->
          expr(not exists(tags, name == ^tag_pattern))

        :matches ->
          if regex_pattern?(tag_pattern) do
            regex = compile_regex(tag_pattern)
            expr(exists(tags, fragment("? ~ ?", name, ^regex)))
          else
            # Handle glob pattern like "tag-*"
            like_pattern = glob_to_like_pattern(tag_pattern)
            expr(exists(tags, like(name, ^like_pattern)))
          end

        :not_matches ->
          if regex_pattern?(tag_pattern) do
            regex = compile_regex(tag_pattern)
            expr(not exists(tags, fragment("? ~ ?", name, ^regex)))
          else
            # Handle glob pattern like "tag-*"
            like_pattern = glob_to_like_pattern(tag_pattern)
            expr(not exists(tags, like(name, ^like_pattern)))
          end
      end
    end

    defp regex_pattern?(pattern) do
      String.starts_with?(pattern, "/") and String.ends_with?(pattern, "/")
    end

    defp compile_regex(pattern) do
      # Remove leading and trailing slashes
      regex_str = String.slice(pattern, 1..-2//1)
      regex_str
    end

    defp glob_to_like_pattern(pattern) do
      pattern
      |> String.replace("*", "%")
      |> String.replace("?", "_")
    end
  end
end
