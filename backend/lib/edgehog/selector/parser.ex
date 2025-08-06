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

defmodule Edgehog.Selector.Parser do
  @moduledoc false
  import NimbleParsec

  alias Edgehog.Selector.AST.AttributeFilter
  alias Edgehog.Selector.AST.BinaryOp
  alias Edgehog.Selector.AST.TagFilter

  # Semi formal definition of the selector grammar
  # Literals are wrapped in single quotes
  #
  # in_op                 := 'in'       # case insensitive
  # not_in_op             := 'not in'   # case insensitive
  # matches_op            := '~='       # case sensitive
  # not_matches_op        := '!~='      # case sensitive
  # and_op                := 'and'      # case insensitive
  # or_op                 := 'or'       # case insensitive
  # attribute_operator    := '==' | '!=' | '>' | '>=' | '<' | '<='
  # double_quoted_string  := '"' string '"'
  # regex_pattern         := '/' regex_content '/'
  # key                   := string
  # tag_value             := double_quoted_string | regex_pattern
  # attribute             := 'attributes["' namespace ':' key '"]'
  # attribute_value       := 'datetime(' double_quoted_string ')'
  #                          | 'now()'
  #                          | 'binaryblob(' double_quoted_string ')'
  #                          | double_quoted_string
  #                          | boolean
  #                          | number
  # attribute_filter      := attribute attribute_operator attribute_value
  #                          | attribute_value in_op attribute      # TODO: not implemented
  #                          | attribute_value not_in_op attribute  # TODO: not implemented
  # tag_filter            := double_quoted_string in_op 'tags'
  #                          | double_quoted_string not_in_op 'tags'
  #                          | (double_quoted_string | regex_pattern) matches_op 'tags'
  #                          | (double_quoted_string | regex_pattern) not_matches_op 'tags'
  # filter                := tag_filter | attribute_filter
  # factor                := ( expression ) | filter
  # term                  := factor and_op term | factor
  # expression            := term or_op expression | term
  # selector              := expression

  blankspace = ignore(ascii_string([?\s, ?\n, ?\r, ?\t], min: 1))

  in_operator =
    [?i, ?I]
    |> ascii_char()
    |> ascii_char([?n, ?N])
    |> label("IN")
    |> replace(:in)

  not_in_operator =
    [?n, ?N]
    |> ascii_char()
    |> ascii_char([?o, ?O])
    |> ascii_char([?t, ?T])
    |> concat(blankspace)
    |> ascii_char([?i, ?I])
    |> ascii_char([?n, ?N])
    |> label("NOT IN")
    |> replace(:not_in)

  matches_operator =
    "~="
    |> string()
    |> label("~=")
    |> replace(:matches)

  not_matches_operator =
    "!~="
    |> string()
    |> label("!~=")
    |> replace(:not_matches)

  and_operator =
    [?a, ?A]
    |> ascii_char()
    |> ascii_char([?n, ?N])
    |> ascii_char([?d, ?D])
    |> label("AND")
    |> replace(:and)

  or_operator =
    [?o, ?O]
    |> ascii_char()
    |> ascii_char([?r, ?R])
    |> label("OR")
    |> replace(:or)

  # We also allow uppercase for namespaces to support the GraphQL-like syntax
  namespace = ascii_string([?a..?z, ?A..?Z, ?-, ?_], min: 1)

  key = ascii_string([?a..?z, ?-, ?_], min: 1)

  attribute =
    "attributes[\""
    |> string()
    |> ignore()
    |> concat(namespace)
    |> ignore(ascii_char([?:]))
    |> concat(key)
    |> ignore(string("\"]"))
    |> label("attribute")

  # Order is important here, e.g. >= must come before >, otherwise the latter will always match first
  attribute_operator =
    [
      "==" |> string() |> replace(:==),
      "!=" |> string() |> replace(:!=),
      ">=" |> string() |> replace(:>=),
      ">" |> string() |> replace(:>),
      "<=" |> string() |> replace(:<=),
      "<" |> string() |> replace(:<)
    ]
    |> choice()
    |> label("operator")

  datetime_value =
    "datetime(\""
    |> string()
    |> ignore()
    |> ascii_string([not: ?"], min: 1)
    |> ignore(string("\")"))
    |> label("datetime(ISO8601) value")
    |> unwrap_and_tag(:datetime)

  now_value =
    "now()"
    |> string()
    |> ignore()
    |> label("now()")
    |> replace(:now)
    # :now is typed as :datetime
    |> unwrap_and_tag(:datetime)

  binaryblob_value =
    "binaryblob(\""
    |> string()
    |> ignore()
    |> ascii_string([not: ?"], min: 1)
    |> ignore(string("\")"))
    |> label("binaryblob(base64) value")
    |> unwrap_and_tag(:binaryblob)

  double_quoted_string =
    [?"]
    |> ascii_char()
    |> ignore()
    |> repeat(
      [?"]
      |> ascii_char()
      |> lookahead_not()
      |> choice([
        ~S(\") |> string() |> replace(?"),
        utf8_char([])
      ])
    )
    |> ignore(ascii_char([?"]))
    |> reduce({Kernel, :to_string, []})

  regex_pattern =
    [?/]
    |> ascii_char()
    |> repeat(
      [?/]
      |> ascii_char()
      |> lookahead_not()
      |> choice([
        ~S(\/) |> string() |> replace(?/),
        utf8_char([])
      ])
    )
    |> ascii_char([?/])
    |> reduce({Kernel, :to_string, []})

  tag_pattern =
    choice([
      regex_pattern,
      double_quoted_string
    ])

  string_value =
    unwrap_and_tag(double_quoted_string, :string)

  boolean_value =
    [
      "true" |> string() |> replace(true),
      "false" |> string() |> replace(false)
    ]
    |> choice()
    |> label("boolean value")
    |> unwrap_and_tag(:boolean)

  positive_integer = integer(min: 1)

  negative_integer =
    [?-]
    |> ascii_char()
    |> ignore()
    |> integer(min: 1)
    |> map({Kernel, :-, []})

  integer_value =
    [
      negative_integer,
      positive_integer
    ]
    |> choice()
    |> lookahead_not(ascii_char([?.]))

  float_value =
    [?-]
    |> ascii_char()
    |> optional()
    |> ascii_string([?0..?9], min: 1)
    |> ignore(ascii_char([?.]))
    |> ascii_string([?0..?9], min: 1)
    |> post_traverse(:parse_float)

  # In the attribute filters we conflate all numeric types to the :number type, because the selector
  # does not give type hints about a value being an integer/longinteger/double and we want to match
  # `== 42` even if the value is `42.0` and viceversa (and numeric attribute values are all converted
  # to PostgreSQL decimal anyway)
  number_value =
    [
      integer_value,
      float_value
    ]
    |> choice()
    |> label("number value")
    |> unwrap_and_tag(:number)

  attribute_value =
    [
      datetime_value,
      now_value,
      binaryblob_value,
      string_value,
      boolean_value,
      number_value
    ]
    |> choice()
    |> label("attribute value")

  attribute_filter =
    attribute
    |> optional(blankspace)
    |> concat(attribute_operator)
    |> optional(blankspace)
    |> concat(attribute_value)
    |> post_traverse(:finalize_attribute_filter)
    |> label("attribute filter")

  tag_filter =
    [
      # matches and not_matches can use both quoted strings and regex patterns
      tag_pattern
      |> concat(blankspace)
      |> choice([matches_operator, not_matches_operator])
      |> concat(blankspace)
      |> ignore(string("tags")),
      # in and not_in can only use quoted strings
      double_quoted_string
      |> concat(blankspace)
      |> choice([in_operator, not_in_operator])
      |> concat(blankspace)
      |> ignore(string("tags"))
    ]
    |> choice()
    |> post_traverse(:finalize_tag_filter)
    |> label("tag filter")

  filter =
    choice([
      tag_filter,
      attribute_filter
    ])

  factor =
    [
      [?(]
      |> ascii_char()
      |> ignore()
      |> optional(blankspace)
      |> concat(parsec(:expression))
      |> optional(blankspace)
      |> ignore(ascii_char([?)])),
      filter
    ]
    |> choice()
    |> label("factor")

  defcombinatorp :term,
                 [
                   factor
                   |> concat(blankspace)
                   |> ignore(and_operator)
                   |> concat(blankspace)
                   |> concat(parsec(:term))
                   |> post_traverse(:finalize_and),
                   factor
                 ]
                 |> choice()
                 |> label("term")

  defcombinatorp :expression,
                 [
                   :term
                   |> parsec()
                   |> concat(blankspace)
                   |> ignore(or_operator)
                   |> concat(blankspace)
                   |> concat(parsec(:expression))
                   |> post_traverse(:finalize_or),
                   parsec(:term)
                 ]
                 |> choice()
                 |> label("expression")

  selector =
    blankspace
    |> optional()
    |> parsec(:expression)
    |> optional(blankspace)
    |> eos()

  defparsec :parse, selector

  defp finalize_tag_filter(rest, [operator, tag], context, _line, _column) do
    node = %TagFilter{tag: tag, operator: operator}
    {rest, [node], context}
  end

  defp finalize_attribute_filter(rest, [{type, value}, operator, key, namespace], context, _line, _column) do
    # This function just passes the parsed value as-is without performing any other checks (e.g. if
    # the operator is valid for that value, if the datetime is a valid ISO8601 etc.).
    # All these semantic checks will be performed when traversing the tree (see
    # `AttributeFilter.validate_and_cast/1`)
    node = %AttributeFilter{
      # Normalize namespace to lowercase
      namespace: String.downcase(namespace),
      key: key,
      operator: operator,
      type: type,
      value: value
    }

    {rest, [node], context}
  end

  defp finalize_and(rest, [rhs, lhs], context, _line, _column) do
    node = %BinaryOp{operator: :and, lhs: lhs, rhs: rhs}
    {rest, [node], context}
  end

  defp finalize_or(rest, [rhs, lhs], context, _line, _column) do
    node = %BinaryOp{operator: :or, lhs: lhs, rhs: rhs}
    {rest, [node], context}
  end

  defp parse_float(rest, [fractional, integral | maybe_sign], context, _line, _column) do
    float_string = integral <> "." <> fractional

    case Float.parse(float_string) do
      {float, ""} -> {rest, [maybe_negate(float, maybe_sign)], context}
      _ -> {:error, "expected float"}
    end
  end

  defp maybe_negate(value, []) when is_number(value) do
    value
  end

  defp maybe_negate(value, [?-]) when is_number(value) do
    -value
  end
end
