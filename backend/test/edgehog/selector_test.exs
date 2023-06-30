#
# This file is part of Edgehog.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule Edgehog.SelectorTest do
  use Edgehog.DataCase

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  alias Edgehog.Devices
  alias Edgehog.Selector
  alias Edgehog.Selector.AST.{AttributeFilter, BinaryOp, TagFilter}
  alias Edgehog.Selector.Parser.Error

  describe "parse/1" do
    test "correctly parses tag filters" do
      assert {:ok, %TagFilter{operator: :in, tag: "foo"}} == Selector.parse(~s/"foo" IN tags/)
      assert {:ok, %TagFilter{operator: :in, tag: "foo"}} == Selector.parse(~s/"foo" in tags/)

      assert {:ok, %TagFilter{operator: :not_in, tag: "bar"}} ==
               Selector.parse(~s/"bar" not in tags/)

      assert {:ok, %TagFilter{operator: :not_in, tag: "bar"}} ==
               Selector.parse(~s/"bar" NOT iN tags/)
    end

    test "correctly parses attribute filters" do
      assert {:ok,
              %AttributeFilter{
                operator: :==,
                namespace: "foo",
                key: "model",
                type: :string,
                value: "baz"
              }} == Selector.parse(~s/attributes["foo:model"] == "baz"/)

      assert {:ok,
              %AttributeFilter{
                operator: :>,
                namespace: "foo",
                key: "answer",
                type: :number,
                value: 41
              }} == Selector.parse(~s/attributes["foo:answer"] > 41/)

      assert {:ok,
              %AttributeFilter{
                operator: :<=,
                namespace: "foo",
                key: "answer",
                type: :number,
                value: 43.0
              }} == Selector.parse(~s/attributes["foo:answer"] <= 43.0/)

      assert {:ok,
              %AttributeFilter{
                operator: :<,
                namespace: "baz",
                key: "service_date",
                type: :datetime,
                value: :now
              }} == Selector.parse(~s/attributes["baz:service_date"] < now()/)

      assert {:ok,
              %AttributeFilter{
                operator: :>=,
                namespace: "baz",
                key: "production_date",
                type: :datetime,
                value: "2022-06-29T16:46:15.00Z"
              }} ==
               Selector.parse(
                 ~s/attributes["baz:production_date"] >= datetime("2022-06-29T16:46:15.00Z")/
               )

      assert {:ok,
              %AttributeFilter{
                operator: :!=,
                namespace: "baz",
                key: "enabled",
                type: :boolean,
                value: true
              }} == Selector.parse(~s/attributes["baz:enabled"] != true/)

      assert {:ok,
              %AttributeFilter{
                operator: :==,
                namespace: "custom",
                key: "firmware_blob",
                type: :binaryblob,
                value: "ZmlybXdhcmU="
              }} ==
               Selector.parse(
                 ~s/attributes["custom:firmware_blob"] == binaryblob("ZmlybXdhcmU=")/
               )
    end

    test "correctly parses binary operations" do
      assert {:ok,
              %BinaryOp{
                operator: :and,
                lhs: %TagFilter{operator: :in, tag: "foo"},
                rhs: %TagFilter{operator: :not_in, tag: "bar"}
              }} ==
               Selector.parse(~s/"foo" in tags and "bar" not in tags/)

      assert {:ok,
              %BinaryOp{
                operator: :and,
                lhs: %TagFilter{operator: :in, tag: "foo"},
                rhs: %TagFilter{operator: :not_in, tag: "bar"}
              }} ==
               Selector.parse(~s/"foo" in tags aNd "bar" not in tags/)

      assert {:ok,
              %BinaryOp{
                operator: :or,
                lhs: %TagFilter{operator: :in, tag: "foo"},
                rhs: %TagFilter{operator: :not_in, tag: "bar"}
              }} ==
               Selector.parse(~s/"foo" in tags OR "bar" not in tags/)

      assert {:ok,
              %BinaryOp{
                operator: :or,
                lhs: %TagFilter{operator: :in, tag: "foo"},
                rhs: %TagFilter{operator: :not_in, tag: "bar"}
              }} ==
               Selector.parse(~s/"foo" in tags or "bar" not in tags/)
    end

    test "correctly handles precedence in binary operations" do
      assert {:ok,
              %BinaryOp{
                operator: :or,
                lhs: %TagFilter{operator: :in, tag: "foo"},
                rhs: %BinaryOp{
                  operator: :and,
                  lhs: %TagFilter{operator: :not_in, tag: "bar"},
                  rhs: %TagFilter{operator: :in, tag: "baz"}
                }
              }} ==
               Selector.parse(~s/"foo" in tags or "bar" not in tags and "baz" in tags/)

      assert {:ok,
              %BinaryOp{
                operator: :and,
                lhs: %BinaryOp{
                  operator: :or,
                  lhs: %TagFilter{operator: :in, tag: "foo"},
                  rhs: %TagFilter{operator: :not_in, tag: "bar"}
                },
                rhs: %TagFilter{operator: :in, tag: "baz"}
              }} ==
               Selector.parse(~s/("foo" in tags or "bar" not in tags) and "baz" in tags/)

      assert {:ok,
              %BinaryOp{
                lhs: %TagFilter{operator: :in, tag: "foo"},
                operator: :or,
                rhs: %BinaryOp{
                  lhs: %BinaryOp{
                    operator: :and,
                    lhs: %TagFilter{operator: :not_in, tag: "bar"},
                    rhs: %TagFilter{operator: :in, tag: "baz"}
                  },
                  operator: :or,
                  rhs: %TagFilter{operator: :in, tag: "fuu"}
                }
              }} ==
               Selector.parse(
                 ~s/"foo" in tags or "bar" not in tags and "baz" in tags or "fuu" in tags/
               )

      assert {:ok,
              %BinaryOp{
                operator: :and,
                lhs: %BinaryOp{
                  operator: :or,
                  lhs: %TagFilter{operator: :in, tag: "foo"},
                  rhs: %TagFilter{operator: :not_in, tag: "bar"}
                },
                rhs: %BinaryOp{
                  operator: :or,
                  lhs: %TagFilter{operator: :in, tag: "baz"},
                  rhs: %TagFilter{operator: :in, tag: "fuu"}
                }
              }} ==
               Selector.parse(
                 ~s/("foo" in tags or "bar" not in tags) and ("baz" in tags or "fuu" in tags)/
               )
    end

    test "returns error with syntax errors" do
      assert {:error, %Error{}} = Selector.parse(~s/"missingquote in tags/)
      assert {:error, %Error{}} = Selector.parse(~s/"typo" in tagz/)
      assert {:error, %Error{}} = Selector.parse(~s/attribute["insteadof:attributes"] == 4/)
      assert {:error, %Error{}} = Selector.parse(~s/attributes["custom:key"] == 3.42.1.3/)
      assert {:error, %Error{}} = Selector.parse(~s/attributes["unmatched:parens" == "foo"/)
      assert {:error, %Error{}} = Selector.parse(~s/"foo" in tags and or "bar" in tags/)
    end
  end

  describe "to_ecto_query/1" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      device_foo_10 =
        device_fixture(realm)
        |> add_tags(["foo"])
        |> add_custom_attributes(%{baz: %{type: :integer, value: 10}})

      device_bar_10 =
        device_fixture(realm)
        |> add_tags(["bar"])
        |> add_custom_attributes(%{baz: %{type: :integer, value: 10}})

      device_foo_20 =
        device_fixture(realm)
        |> add_tags(["foo"])
        |> add_custom_attributes(%{baz: %{type: :integer, value: 20}})

      device_bar_20 =
        device_fixture(realm)
        |> add_tags(["bar"])
        |> add_custom_attributes(%{baz: %{type: :integer, value: 20}})

      {:ok,
       device_foo_10: device_foo_10,
       device_bar_10: device_bar_10,
       device_foo_20: device_foo_20,
       device_bar_20: device_bar_20}
    end

    test "accepts a root %TagFilter{} node and generates a query", %{
      device_foo_10: device_foo_10,
      device_foo_20: device_foo_20
    } do
      assert {:ok, %Ecto.Query{} = query} =
               %TagFilter{operator: :in, tag: "foo"} |> Selector.to_ecto_query()

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Repo.preload_defaults()

      assert is_list(result)
      assert length(result) == 2
      assert device_foo_10 in result
      assert device_foo_20 in result
    end

    test "accepts a root %AttributeFilter{} node and generates a query", %{
      device_foo_10: device_foo_10,
      device_bar_10: device_bar_10
    } do
      assert {:ok, %Ecto.Query{} = query} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "baz",
                 operator: :==,
                 type: :number,
                 value: 10
               }
               |> Selector.to_ecto_query()

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Repo.preload_defaults()

      assert is_list(result)
      assert length(result) == 2
      assert device_foo_10 in result
      assert device_bar_10 in result
    end

    test "accepts a root %BinaryOp{} node and generates a query", %{
      device_foo_10: device_foo_10
    } do
      assert {:ok, %Ecto.Query{} = query} =
               %BinaryOp{
                 operator: :and,
                 lhs: %TagFilter{operator: :in, tag: "foo"},
                 rhs: %AttributeFilter{
                   namespace: "custom",
                   key: "baz",
                   operator: :==,
                   type: :number,
                   value: 10
                 }
               }
               |> Selector.to_ecto_query()

      assert [device_foo_10] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload_defaults()
    end

    test "accepts a binary selector and generates a query", %{
      device_bar_10: device_bar_10,
      device_foo_20: device_foo_20,
      device_bar_20: device_bar_20
    } do
      assert {:ok, %Ecto.Query{} = query} =
               Selector.to_ecto_query(~s/"bar" in tags or attributes["custom:baz"] > 15/)

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Repo.preload_defaults()

      assert is_list(result)
      assert length(result) == 3
      assert device_bar_10 in result
      assert device_foo_20 in result
      assert device_bar_20 in result
    end
  end

  defp add_custom_attributes(%Devices.Device{} = device, kv_map) do
    custom_attributes =
      for {k, v} <- kv_map, k = to_string(k) do
        %{namespace: :custom, key: k, typed_value: v}
      end

    {:ok, device} = Devices.update_device(device, %{custom_attributes: custom_attributes})
    device
  end
end
