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

defmodule Edgehog.Devices.Selector.AST.AttributeFilterTest do
  use Edgehog.DataCase

  import Ecto.Query
  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  alias Edgehog.Devices
  alias Edgehog.Devices.Selector.AST.AttributeFilter
  alias Edgehog.Devices.Selector.Parser.Error
  alias Edgehog.Repo

  describe "to_ecto_dynamic_query/1 returns %Parser.Error{}" do
    test "with invalid operator for string" do
      invalid_operators = [:>, :>=, :<, :<=]

      Enum.each(invalid_operators, fn operator ->
        assert {:error, %Error{message: message}} =
                 %AttributeFilter{
                   namespace: "custom",
                   key: "foo",
                   operator: operator,
                   type: :string,
                   value: "bar"
                 }
                 |> AttributeFilter.to_ecto_dynamic_query()

        assert message =~ "invalid operator"
      end)
    end

    test "with invalid operator for binaryblob" do
      invalid_operators = [:>, :>=, :<, :<=]

      Enum.each(invalid_operators, fn operator ->
        assert {:error, %Error{message: message}} =
                 %AttributeFilter{
                   namespace: "custom",
                   key: "foo",
                   operator: operator,
                   type: :binaryblob,
                   value: "YmFy"
                 }
                 |> AttributeFilter.to_ecto_dynamic_query()

        assert message =~ "invalid operator"
      end)
    end

    test "with invalid namespace" do
      assert {:error, %Error{message: message}} =
               %AttributeFilter{
                 namespace: "invalid",
                 key: "foo",
                 operator: :==,
                 type: :string,
                 value: "bar"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      assert message =~ "invalid namespace"
    end

    test "with invalid datetime value" do
      assert {:error, %Error{message: message}} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "foo",
                 operator: :>,
                 type: :datetime,
                 value: "not ISO8601"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      assert message =~ "invalid ISO8601 value"
    end

    test "with invalid binaryblob value" do
      assert {:error, %Error{message: message}} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "foo",
                 operator: :==,
                 type: :binaryblob,
                 value: "not base64"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      assert message =~ "invalid base64 value"
    end
  end

  describe "to_ecto_dynamic_query/1 returns a dynamic query matching boolean attributes" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      device_true =
        device_fixture(realm)
        |> add_custom_attributes(%{foo: %{type: :boolean, value: true}})

      device_false =
        device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A")
        |> add_custom_attributes(%{foo: %{type: :boolean, value: false}})

      {:ok, device_true: device_true, device_false: device_false}
    end

    test "with == operator", %{device_true: device_true} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "foo",
                 operator: :==,
                 type: :boolean,
                 value: true
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_true] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end

    test "with != operator", %{device_false: device_false} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "foo",
                 operator: :!=,
                 type: :boolean,
                 value: true
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_false] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end
  end

  describe "to_ecto_dynamic_query/1 returns a dynamic query matching string attributes" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      device_bar =
        device_fixture(realm)
        |> add_custom_attributes(%{foo: %{type: :string, value: "bar"}})

      device_baz =
        device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A")
        |> add_custom_attributes(%{foo: %{type: :string, value: "baz"}})

      {:ok, device_bar: device_bar, device_baz: device_baz}
    end

    test "with == operator", %{device_bar: device_bar} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "foo",
                 operator: :==,
                 type: :string,
                 value: "bar"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_bar] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end

    test "with != operator", %{device_baz: device_baz} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "foo",
                 operator: :!=,
                 type: :string,
                 value: "bar"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_baz] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end
  end

  describe "to_ecto_dynamic_query/1 returns a dynamic query matching binaryblob attributes" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      device_bar =
        device_fixture(realm)
        |> add_custom_attributes(%{foo: %{type: :binaryblob, value: "YmFy"}})

      device_baz =
        device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A")
        |> add_custom_attributes(%{foo: %{type: :binaryblob, value: "YmF6"}})

      {:ok, device_bar: device_bar, device_baz: device_baz}
    end

    test "with == operator", %{device_bar: device_bar} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "foo",
                 operator: :==,
                 type: :binaryblob,
                 value: "YmFy"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_bar] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end

    test "with != operator", %{device_baz: device_baz} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "foo",
                 operator: :!=,
                 type: :binaryblob,
                 value: "YmFy"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_baz] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end
  end

  describe "to_ecto_dynamic_query/1 returns a dynamic query matching number (longinteger, integer and double) attributes" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      device_41 =
        device_fixture(realm)
        |> add_custom_attributes(%{answer: %{type: :longinteger, value: 41}})

      device_42 =
        device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A")
        |> add_custom_attributes(%{answer: %{type: :integer, value: 42}})

      device_43 =
        device_fixture(realm, device_id: "OBZmmuHoTkmh9jsqcCAdaQ")
        |> add_custom_attributes(%{answer: %{type: :double, value: 43.0}})

      {:ok, device_41: device_41, device_42: device_42, device_43: device_43}
    end

    test "with == operator", %{device_42: device_42} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "answer",
                 operator: :==,
                 type: :number,
                 value: 42
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_42] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end

    test "with != operator", %{device_41: device_41, device_43: device_43} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "answer",
                 operator: :!=,
                 type: :number,
                 value: 42.0
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Repo.preload([:tags, :custom_attributes])

      assert is_list(result)
      assert length(result) == 2
      assert device_41 in result
      assert device_43 in result
    end

    test "with > operator", %{device_43: device_43} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "answer",
                 operator: :>,
                 type: :number,
                 value: 42
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_43] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end

    test "with >= operator", %{device_42: device_42, device_43: device_43} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "answer",
                 operator: :>=,
                 type: :number,
                 value: 42
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Repo.preload([:tags, :custom_attributes])

      assert is_list(result)
      assert length(result) == 2
      assert device_42 in result
      assert device_43 in result
    end

    test "with < operator", %{device_41: device_41} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "answer",
                 operator: :<,
                 type: :number,
                 value: 42.0
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_41] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end

    test "with <= operator", %{device_41: device_41, device_42: device_42} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "answer",
                 operator: :<=,
                 type: :number,
                 value: 42.0
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Repo.preload([:tags, :custom_attributes])

      assert is_list(result)
      assert length(result) == 2
      assert device_41 in result
      assert device_42 in result
    end
  end

  describe "to_ecto_dynamic_query/1 returns a dynamic query matching datetime attributes" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      device_past =
        device_fixture(realm)
        |> add_custom_attributes(%{
          production_date: %{type: :datetime, value: "2020-06-28T16:00:00"}
        })

      device_present =
        device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A")
        |> add_custom_attributes(%{
          production_date: %{type: :datetime, value: "2022-06-29T16:00:00Z"}
        })

      device_future =
        device_fixture(realm, device_id: "OBZmmuHoTkmh9jsqcCAdaQ")
        |> add_custom_attributes(%{
          production_date: %{type: :datetime, value: "2122-06-30T16:00:00"}
        })

      {:ok,
       device_past: device_past, device_present: device_present, device_future: device_future}
    end

    test "with == operator", %{device_present: device_present} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "production_date",
                 operator: :==,
                 type: :datetime,
                 value: "2022-06-29T16:00:00Z"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_present] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end

    test "with != operator", %{
      device_past: device_past,
      device_future: device_future
    } do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "production_date",
                 operator: :!=,
                 type: :datetime,
                 value: "2022-06-29T16:00:00Z"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Repo.preload([:tags, :custom_attributes])

      assert is_list(result)
      assert length(result) == 2
      assert device_past in result
      assert device_future in result
    end

    test "with > operator", %{device_future: device_future} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "production_date",
                 operator: :>,
                 type: :datetime,
                 value: "2022-06-29T16:00:00Z"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_future] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end

    test "with >= operator", %{device_present: device_present, device_future: device_future} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "production_date",
                 operator: :>=,
                 type: :datetime,
                 value: "2022-06-29T16:00:00Z"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Repo.preload([:tags, :custom_attributes])

      assert is_list(result)
      assert length(result) == 2
      assert device_present in result
      assert device_future in result
    end

    test "with < operator", %{device_past: device_past} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "production_date",
                 operator: :<,
                 type: :datetime,
                 value: "2022-06-29T16:00:00Z"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_past] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end

    test "with <= operator", %{device_past: device_past, device_present: device_present} do
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "production_date",
                 operator: :<=,
                 type: :datetime,
                 value: "2022-06-29T16:00:00Z"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Repo.preload([:tags, :custom_attributes])

      assert is_list(result)
      assert length(result) == 2
      assert device_past in result
      assert device_present in result
    end

    test "with < operator and :now value", %{
      device_past: device_past,
      device_present: device_present
    } do
      # Note to future developers, time travelers and people with poorly adjusted system clocks:
      # this test will fail if executed before 2022-06-29T16:00:00Z or after 2122-06-30T16:00:00Z
      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "production_date",
                 operator: :<,
                 type: :datetime,
                 value: :now
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Repo.preload([:tags, :custom_attributes])

      assert is_list(result)
      assert length(result) == 2
      assert device_past in result
      assert device_present in result
    end
  end

  describe "to_ecto_dynamic_query/1 does not match" do
    setup do
      cluster = cluster_fixture()
      {:ok, realm: realm_fixture(cluster)}
    end

    test "devices without the indicated attribute when using !=", %{realm: realm} do
      _device_bar =
        device_fixture(realm)
        |> add_custom_attributes(%{foo: %{type: :string, value: "bar"}})

      device_baz =
        device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A")
        |> add_custom_attributes(%{foo: %{type: :string, value: "baz"}})

      _device_no_foo_attr =
        device_fixture(realm, device_id: "OBZmmuHoTkmh9jsqcCAdaQ")
        |> add_custom_attributes(%{not_foo: %{type: :string, value: "baz"}})

      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "foo",
                 operator: :!=,
                 type: :string,
                 value: "bar"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_baz] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
    end

    test "devices with the indicated attribute with a different type", %{realm: realm} do
      device_string_foob =
        device_fixture(realm)
        |> add_custom_attributes(%{foo: %{type: :string, value: "foob"}})

      _device_binary_foob =
        device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A")
        |> add_custom_attributes(%{foo: %{type: :binaryblob, value: "foob"}})

      assert {:ok, dynamic} =
               %AttributeFilter{
                 namespace: "custom",
                 key: "foo",
                 operator: :==,
                 type: :string,
                 value: "foob"
               }
               |> AttributeFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_string_foob] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Repo.preload([:tags, :custom_attributes])
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
