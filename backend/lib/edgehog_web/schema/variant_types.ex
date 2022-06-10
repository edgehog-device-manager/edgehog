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

defmodule EdgehogWeb.Schema.VariantTypes do
  use Absinthe.Schema.Notation

  @supported_types [
    :double,
    :integer,
    :boolean,
    :longinteger,
    :string,
    :binaryblob,
    :datetime
  ]

  enum :variant_type do
    @desc "Double type"
    value :double
    @desc "32 bit integer type"
    value :integer
    @desc "Boolean type"
    value :boolean

    @desc """
    64 bit integer type. When this is the type, the value will be a string representing the number.
    This is done to avoid representation errors when using JSON Numbers.
    """
    value :longinteger
    @desc "String type"
    value :string
    @desc "Binary blob type. When this is the type, the value will be Base64 encoded."
    value :binaryblob
    @desc "Datetime type. When this is the type, the value will be an ISO8601 timestamp."
    value :datetime
  end

  @desc """
  A variant value. It can contain any JSON value. The value will be checked together with the
  type to verify whether it's valid.
  """
  scalar :variant_value, name: "VariantValue" do
    # We encode and decode values as-is, proper encoding/decoding and validation will be handled
    # one level higher when both the type and the value are available at once.
    # See encode/2 for encoding and the Ecto.JSONVariant module for decoding.
    serialize &Function.identity/1
    parse &decode_variant_value/1
  end

  # Handle all scalar JSON types and decode them as-is
  defp decode_variant_value(%Absinthe.Blueprint.Input.Float{value: value}), do: {:ok, value}
  defp decode_variant_value(%Absinthe.Blueprint.Input.Integer{value: value}), do: {:ok, value}
  defp decode_variant_value(%Absinthe.Blueprint.Input.String{value: value}), do: {:ok, value}
  defp decode_variant_value(%Absinthe.Blueprint.Input.Null{}), do: {:ok, nil}
  defp decode_variant_value(_), do: :error

  # Handle encoding with type + value
  # :binaryblob gets converted to base64
  def encode_variant_value(:binaryblob, value) when is_binary(value) do
    {:ok, Base.encode64(value)}
  end

  # :datetime gets converted to ISO8601
  def encode_variant_value(:datetime, %DateTime{} = value) do
    {:ok, DateTime.to_iso8601(value)}
  end

  # :longinteger gets converted to string to avoid JSON representation problems
  def encode_variant_value(:longinteger, value) when is_integer(value),
    do: {:ok, to_string(value)}

  # Everything else is encoded as itself
  def encode_variant_value(type, value) when type in @supported_types, do: {:ok, value}
  def encode_variant_value(_type, _value), do: {:error, :unsupported_type}
end
