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

defmodule Ecto.JSONVariantTest do
  use ExUnit.Case
  alias Ecto.JSONVariant

  import Ecto.Changeset

  @types %{
    variant: JSONVariant
  }

  describe "cast/1 with double type" do
    test "correctly handles a double" do
      assert {:ok, %{variant: %JSONVariant{type: :double, value: 42.0}}} ==
               cast_and_apply(%{"variant" => %{"type" => "double", "value" => 42.0}})
    end

    test "correctly handles an integer" do
      assert {:ok, %{variant: %JSONVariant{type: :double, value: 42.0}}} ===
               cast_and_apply(%{"variant" => %{"type" => "double", "value" => 42}})
    end

    test "correctly handles a string" do
      assert {:ok, %{variant: %JSONVariant{type: :double, value: 42.0}}} ===
               cast_and_apply(%{"variant" => %{"type" => "double", "value" => "42"}})
    end

    test "fails with invalid value" do
      assert {:error, %Ecto.Changeset{}} =
               cast_and_apply(%{"variant" => %{"type" => "double", "value" => "foobar"}})
    end
  end

  describe "cast/1 with integer type" do
    test "correctly handles an integer" do
      assert {:ok, %{variant: %JSONVariant{type: :integer, value: 42}}} ==
               cast_and_apply(%{"variant" => %{"type" => "integer", "value" => 42}})
    end

    test "correctly handles a string" do
      assert {:ok, %{variant: %JSONVariant{type: :integer, value: 42}}} ==
               cast_and_apply(%{"variant" => %{"type" => "integer", "value" => "42"}})
    end

    test "fails with invalid value" do
      assert {:error, %Ecto.Changeset{}} =
               cast_and_apply(%{"variant" => %{"type" => "integer", "value" => "foobar"}})
    end

    test "fails with out of range value" do
      assert {:error, %Ecto.Changeset{}} =
               cast_and_apply(%{"variant" => %{"type" => "integer", "value" => 2_000_000_000_000}})
    end
  end

  describe "cast/1 with boolean type" do
    test "correctly handles a boolean" do
      assert {:ok, %{variant: %JSONVariant{type: :boolean, value: true}}} ==
               cast_and_apply(%{"variant" => %{"type" => "boolean", "value" => true}})
    end

    test "correctly handles a string" do
      assert {:ok, %{variant: %JSONVariant{type: :boolean, value: true}}} ==
               cast_and_apply(%{"variant" => %{"type" => "boolean", "value" => "true"}})
    end

    test "correctly handles an integer string" do
      assert {:ok, %{variant: %JSONVariant{type: :boolean, value: true}}} ==
               cast_and_apply(%{"variant" => %{"type" => "boolean", "value" => "1"}})
    end

    test "fails with invalid value" do
      assert {:error, %Ecto.Changeset{}} =
               cast_and_apply(%{"variant" => %{"type" => "boolean", "value" => "foobar"}})
    end
  end

  describe "cast/1 with longinteger type" do
    test "correctly handles an longinteger" do
      assert {:ok, %{variant: %JSONVariant{type: :longinteger, value: 42}}} ==
               cast_and_apply(%{"variant" => %{"type" => "longinteger", "value" => 42}})
    end

    test "correctly handles a string" do
      assert {:ok, %{variant: %JSONVariant{type: :longinteger, value: 42}}} ==
               cast_and_apply(%{"variant" => %{"type" => "longinteger", "value" => "42"}})
    end

    test "fails with invalid value" do
      assert {:error, %Ecto.Changeset{}} =
               cast_and_apply(%{"variant" => %{"type" => "longinteger", "value" => "foobar"}})
    end

    test "fails with out of range value" do
      assert {:error, %Ecto.Changeset{}} =
               cast_and_apply(%{
                 "variant" => %{"type" => "longinteger", "value" => 0x1_FFFF_FFFF_FFFF_FFFF}
               })
    end
  end

  describe "cast/1 with string type" do
    test "correctly handles a valid string" do
      assert {:ok, %{variant: %JSONVariant{type: :string, value: "hello world"}}} ==
               cast_and_apply(%{"variant" => %{"type" => "string", "value" => "hello world"}})
    end

    test "fails with invalid string" do
      assert {:error, %Ecto.Changeset{}} =
               cast_and_apply(%{"variant" => %{"type" => "string", "value" => <<128>>}})
    end

    test "fails with invalid value" do
      assert {:error, %Ecto.Changeset{}} =
               cast_and_apply(%{"variant" => %{"type" => "string", "value" => 42}})
    end
  end

  describe "cast/1 with binaryblob type" do
    test "correctly handles base64" do
      assert {:ok, %{variant: %JSONVariant{type: :binaryblob, value: <<128>>}}} ==
               cast_and_apply(%{"variant" => %{"type" => "binaryblob", "value" => "gA=="}})
    end

    test "fails with invalid value" do
      assert {:error, %Ecto.Changeset{}} =
               cast_and_apply(%{"variant" => %{"type" => "binaryblob", "value" => <<128>>}})
    end
  end

  describe "cast/1 with datetime type" do
    test "correctly handles an ISO8601 timestamp" do
      assert {:ok, %{variant: %JSONVariant{type: :datetime, value: %DateTime{}}}} =
               cast_and_apply(%{
                 "variant" => %{"type" => "datetime", "value" => "2022-06-08T14:30:33.167352Z"}
               })
    end

    test "correctly handles a DateTime" do
      assert {:ok, %{variant: %JSONVariant{type: :datetime, value: %DateTime{}}}} =
               cast_and_apply(%{
                 "variant" => %{"type" => "datetime", "value" => DateTime.utc_now()}
               })
    end

    test "fails with invalid value" do
      assert {:error, %Ecto.Changeset{}} =
               cast_and_apply(%{"variant" => %{"type" => "datetime", "value" => "foobar"}})
    end
  end

  describe "dump and load" do
    test "roundtrip for double" do
      {:ok, %{variant: value}} =
        cast_and_apply(%{"variant" => %{"type" => "double", "value" => 42.0}})

      assert value == dump_load_roundtrip(value)
    end

    test "roundtrip for integer" do
      {:ok, %{variant: value}} =
        cast_and_apply(%{"variant" => %{"type" => "integer", "value" => 42}})

      assert value == dump_load_roundtrip(value)
    end

    test "roundtrip for boolean" do
      {:ok, %{variant: value}} =
        cast_and_apply(%{"variant" => %{"type" => "boolean", "value" => true}})

      assert value == dump_load_roundtrip(value)
    end

    test "roundtrip for longinteger" do
      {:ok, %{variant: value}} =
        cast_and_apply(%{"variant" => %{"type" => "longinteger", "value" => 42}})

      assert value == dump_load_roundtrip(value)
    end

    test "roundtrip for string" do
      {:ok, %{variant: value}} =
        cast_and_apply(%{"variant" => %{"type" => "string", "value" => "hello"}})

      assert value == dump_load_roundtrip(value)
    end

    test "roundtrip for binaryblob" do
      {:ok, %{variant: value}} =
        cast_and_apply(%{"variant" => %{"type" => "binaryblob", "value" => "ZWRnZWhvZw=="}})

      assert value == dump_load_roundtrip(value)
    end

    test "roundtrip for datetime" do
      {:ok, %{variant: value}} =
        cast_and_apply(%{"variant" => %{"type" => "datetime", "value" => DateTime.utc_now()}})

      assert value == dump_load_roundtrip(value)
    end
  end

  def cast_and_apply(params) do
    {%{}, @types}
    |> cast(params, Map.keys(@types))
    |> apply_action(:insert)
  end

  def dump_load_roundtrip(value) do
    {:ok, dumped_value} = JSONVariant.dump(value)

    {:ok, loaded_value} =
      dumped_value
      |> to_string_keys()
      |> JSONVariant.load()

    loaded_value
  end

  def to_string_keys(%{t: t, v: v} = _dumped_value) do
    %{"t" => t, "v" => v}
  end
end
