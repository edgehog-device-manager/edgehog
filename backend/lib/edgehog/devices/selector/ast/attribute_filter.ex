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

defmodule Edgehog.Devices.Selector.AST.AttributeFilter do
  defstruct [:namespace, :key, :operator, :type, :value]

  @type t :: %__MODULE__{
          namespace: String.t(),
          key: String.t(),
          operator: operator,
          type: type,
          value: value
        }

  @type operator :: :== | :!= | :>= | :> | :<= | :<
  @type type :: :boolean | :datetime | :binaryblob | :string | :number
  @type value :: atom | DateTime.t() | binary | String.t() | number

  import Ecto.Query
  alias Edgehog.Devices.Attribute
  alias Edgehog.Devices.Selector.AST.AttributeFilter
  alias Edgehog.Devices.Selector.Parser.Error

  @available_namespaces Ecto.Enum.values(Edgehog.Devices.Attribute, :namespace)
                        |> Enum.map(&to_string/1)

  @doc """
  Validates an `%AttributeFilter{}` and converts it to a dynamic where clause filtering
  `Astarte.Device`s that match the given `%AttributeFilter{}`.

  Returns `{:ok, dynamic_query}` or `{:error, %Parser.Error{}}`
  """
  def to_ecto_dynamic_query(%AttributeFilter{} = attribute_filter) do
    with :ok <- validate(attribute_filter),
         query <- device_ids_matching_attribute_filter(attribute_filter) do
      {:ok, dynamic([d], d.id in subquery(query))}
    end
  end

  defp validate(%AttributeFilter{namespace: namespace} = attribute_filter)
       when namespace in @available_namespaces do
    with :ok <- validate_operator_for_value(attribute_filter) do
      validate_value(attribute_filter)
    end
  end

  defp validate(%AttributeFilter{namespace: namespace, key: key}) do
    message = "invalid namespace #{namespace} in attribute[\"#{namespace}:#{key}\"]"

    {:error, %Error{message: message}}
  end

  # Equality/inequality works for any value
  defp validate_operator_for_value(%AttributeFilter{operator: operator})
       when operator in [:==, :!=] do
    :ok
  end

  # Numeric operators only work with certain types
  defp validate_operator_for_value(%AttributeFilter{operator: operator, type: type})
       when operator in [:>, :>=, :<, :<=] and type in [:number, :datetime] do
    :ok
  end

  defp validate_operator_for_value(attribute_filter) do
    %AttributeFilter{
      namespace: namespace,
      key: key,
      operator: operator,
      type: type
    } = attribute_filter

    message =
      "invalid operator #{operator} for type #{type} in attribute[\"#{namespace}:#{key}\"]"

    {:error, %Error{message: message}}
  end

  defp validate_value(%AttributeFilter{type: :datetime, value: value} = attribute_filter)
       when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, _datetime, _offset} ->
        :ok

      {:error, _reason} ->
        %AttributeFilter{
          namespace: namespace,
          key: key
        } = attribute_filter

        message =
          "invalid ISO8601 value #{value} in filter for attribute[\"#{namespace}:#{key}\"]"

        {:error, %Error{message: message}}
    end
  end

  defp validate_value(%AttributeFilter{type: :binaryblob, value: value} = attribute_filter)
       when is_binary(value) do
    case Base.decode64(value) do
      {:ok, _binaryblob} ->
        :ok

      :error ->
        %AttributeFilter{
          namespace: namespace,
          key: key
        } = attribute_filter

        message = "invalid base64 value #{value} in filter for attribute[\"#{namespace}:#{key}\"]"

        {:error, %Error{message: message}}
    end
  end

  defp validate_value(_attribute_filter) do
    # Everything else needs no further validation
    :ok
  end

  defp device_ids_matching_attribute_filter(%AttributeFilter{} = attribute_filter) do
    %AttributeFilter{
      namespace: namespace,
      key: key,
      operator: operator,
      type: type,
      value: value
    } = attribute_filter

    base_query =
      from a in Attribute,
        where: a.namespace == ^namespace and a.key == ^key,
        select: a.device_id

    base_query
    |> with_correct_type(type)
    |> satisfying_filter(operator, type, value)
  end

  defp with_correct_type(query, type) do
    correct_types = correct_types_for_type(type)

    from a in query, where: fragment("?->>'t'", a.typed_value) in ^correct_types
  end

  # Map the filter types to the corresponding JSONVariant types
  defp correct_types_for_type(:boolean), do: ["boolean"]
  defp correct_types_for_type(:string), do: ["string"]
  defp correct_types_for_type(:datetime), do: ["datetime"]
  defp correct_types_for_type(:binaryblob), do: ["binaryblob"]
  defp correct_types_for_type(:number), do: ["integer", "longinteger", "double"]

  # Utility macro to generate the AST for comparisons with a dynamic (compile-time known) operator
  # This basically translates `comparison(foo, :>, bar)` in the AST equivalent of `foo > bar`
  defmacrop compare(lhs, operator, rhs) do
    {operator, [context: Elixir, import: Kernel], [lhs, rhs]}
  end

  # Utility macro to cast a JSON Variant field to the appropriate type
  # We are sure the cast will succeed since we're already filtering for the correct type
  # This has to be a macro because it's passed inside an Ecto.Query
  defmacrop cast_json_variant(field, type) do
    cast_expression = cast_expression(type)

    quote location: :keep, generated: true do
      fragment(unquote(cast_expression), unquote(field))
    end
  end

  # Probably due to macro-magic, Dialyzer thinks this function never gets called, so we disable
  # the warning to avoid making the CI fail
  @dialyzer {:nowarn_function, cast_expression: 1}
  defp cast_expression(:datetime), do: "(?->>'v')::timestamp"
  defp cast_expression(:number), do: "(?->>'v')::numeric"
  defp cast_expression(:boolean), do: "(?->>'v')::boolean"
  defp cast_expression(type) when type in [:string, :binaryblob], do: "?->>'v'"

  defp satisfying_filter(query, operator, :datetime, :now) do
    # Special case for :now value
    # Generate the current timestamp since we're evaluating the condition
    now = DateTime.utc_now()
    # After that, treat this as a normal datetime value
    satisfying_filter(query, operator, :datetime, now)
  end

  defp satisfying_filter(query, operator, :datetime, value) when is_binary(value) do
    # If the :datetime value is a binary, we must interpret it as ISO8601
    # This will succeed by definition since we already validated this above
    {:ok, datetime, _offset} = DateTime.from_iso8601(value)
    satisfying_filter(query, operator, :datetime, datetime)
  end

  # Generate satisfying_filter/4 for :datetime and :number, supporting all operators
  for type <- [:datetime, :number], operator <- [:==, :!=, :>, :>=, :<, :<=] do
    defp satisfying_filter(query, unquote(operator), unquote(type), value) do
      from a in query,
        where: compare(cast_json_variant(a.typed_value, unquote(type)), unquote(operator), ^value)
    end
  end

  # Generate satisfying_filter/4 for :boolean, :string and :binaryblob, supporting only ==/!=
  for type <- [:boolean, :string, :binaryblob], operator <- [:==, :!=] do
    defp satisfying_filter(query, unquote(operator), unquote(type), value) do
      from a in query,
        where: compare(cast_json_variant(a.typed_value, unquote(type)), unquote(operator), ^value)
    end
  end
end
