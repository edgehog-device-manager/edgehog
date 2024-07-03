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
  use Edgehog.DataCase, async: true

  require Ash.Query
  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures
  alias Edgehog.Devices.Device
  alias Edgehog.Selector
  alias Edgehog.Selector.AST.AttributeFilter
  alias Edgehog.Selector.AST.BinaryOp
  alias Edgehog.Selector.AST.TagFilter
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

  describe "to_ash_expr/1" do
    setup do
      tenant = tenant_fixture()
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)

      device_foo_red =
        device_fixture(realm_id: realm.id, tenant: tenant)
        |> add_tags(["foo", "red"])

      device_bar_red =
        device_fixture(realm_id: realm.id, tenant: tenant)
        |> add_tags(["bar", "red"])

      device_foo_green =
        device_fixture(realm_id: realm.id, tenant: tenant)
        |> add_tags(["foo", "green"])

      device_bar_green =
        device_fixture(realm_id: realm.id, tenant: tenant)
        |> add_tags(["bar", "green"])

      {:ok,
       tenant: tenant,
       device_foo_red: device_foo_red,
       device_bar_red: device_bar_red,
       device_foo_green: device_foo_green,
       device_bar_green: device_bar_green}
    end

    test "accepts a root %TagFilter{} node and generates a query", ctx do
      %{
        tenant: tenant,
        device_foo_red: device_foo_red,
        device_foo_green: device_foo_green
      } = ctx

      expr = %TagFilter{operator: :in, tag: "foo"} |> Selector.to_ash_expr()

      ids =
        Device
        |> Ash.Query.filter(^expr)
        |> Ash.list!(:id, tenant: tenant)

      assert is_list(ids)
      assert length(ids) == 2
      assert device_foo_red.id in ids
      assert device_foo_green.id in ids
    end

    test "accepts a root %BinaryOp{} node and generates a query", ctx do
      %{
        tenant: tenant,
        device_foo_red: device_foo_red
      } = ctx

      expr =
        %BinaryOp{
          operator: :and,
          lhs: %TagFilter{operator: :in, tag: "foo"},
          rhs: %TagFilter{operator: :in, tag: "red"}
        }
        |> Selector.to_ash_expr()

      [id] =
        Device
        |> Ash.Query.filter(^expr)
        |> Ash.list!(:id, tenant: tenant)

      assert device_foo_red.id == id
    end

    test "accepts a binary selector and generates a query", ctx do
      %{
        tenant: tenant,
        device_bar_red: device_bar_red,
        device_foo_green: device_foo_green,
        device_bar_green: device_bar_green
      } = ctx

      assert {:ok, ast_root} = Selector.parse(~s/"bar" in tags or "green" in tags/)
      expr = Selector.to_ash_expr(ast_root)

      ids =
        Device
        |> Ash.Query.filter(^expr)
        |> Ash.list!(:id, tenant: tenant)

      assert is_list(ids)
      assert length(ids) == 3
      assert device_bar_red.id in ids
      assert device_foo_green.id in ids
      assert device_bar_green.id in ids
    end
  end
end
