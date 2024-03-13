#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule Edgehog.DevicesTest do
  use Edgehog.DataCase, async: true

  alias Edgehog.Devices

  describe "devices" do
    alias Edgehog.Devices.Device
    alias Edgehog.Labeling

    import Edgehog.AstarteFixtures
    import Edgehog.DevicesFixtures

    setup do
      cluster = cluster_fixture()

      %{realm: realm_fixture(cluster)}
    end

    @invalid_attrs %{device_id: nil, name: nil}

    test "list_devices/0 returns all devices", %{realm: realm} do
      device = device_fixture(realm)
      assert Devices.list_devices() == [device]
    end

    test "list_devices/1 filters with online", %{realm: realm} do
      device_1 = device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A", online: true)
      _device_2 = device_fixture(realm, device_id: "nWwr7SZiR8CgZN_uKHsAJg", online: false)
      filters = %{online: true}

      assert Devices.list_devices(filters) == [device_1]
    end

    test "list_devices/1 filters with device_id", %{realm: realm} do
      device_1 = device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A")
      _device_2 = device_fixture(realm, device_id: "nWwr7SZiR8CgZN_uKHsAJg")
      filters = %{device_id: "7mc"}

      assert Devices.list_devices(filters) == [device_1]
    end

    test "list_devices/1 filters with system_model_part_number", %{realm: realm} do
      system_model_part_number_1 = "XYZ/1234"

      _system_model_1 =
        system_model_fixture(
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(
          name: "Bar",
          handle: "bar",
          part_numbers: [system_model_part_number_2]
        )

      device_1 =
        device_fixture(realm,
          device_id: "7mcE8JeZQkSzjLyYuh5N9A",
          part_number: system_model_part_number_1
        )

      _device_2 =
        device_fixture(realm,
          device_id: "nWwr7SZiR8CgZN_uKHsAJg",
          part_number: system_model_part_number_2
        )

      filters = %{system_model_part_number: "XYZ"}

      assert Devices.list_devices(filters) == [device_1]
    end

    test "list_devices/1 filters with system_model_name", %{realm: realm} do
      system_model_part_number_1 = "XYZ/1234"

      _system_model_1 =
        system_model_fixture(
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(
          name: "Bar",
          handle: "bar",
          part_numbers: [system_model_part_number_2]
        )

      device_1 =
        device_fixture(realm,
          device_id: "7mcE8JeZQkSzjLyYuh5N9A",
          part_number: system_model_part_number_1
        )

      _device_2 =
        device_fixture(realm,
          device_id: "nWwr7SZiR8CgZN_uKHsAJg",
          part_number: system_model_part_number_2
        )

      filters = %{system_model_name: "oo"}

      assert Devices.list_devices(filters) == [device_1]
    end

    test "list_devices/1 filters with system_model_handle", %{realm: realm} do
      system_model_part_number_1 = "XYZ/1234"

      _system_model_1 =
        system_model_fixture(
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(
          name: "Bar",
          handle: "bar",
          part_numbers: [system_model_part_number_2]
        )

      device_1 =
        device_fixture(realm,
          device_id: "7mcE8JeZQkSzjLyYuh5N9A",
          part_number: system_model_part_number_1
        )

      _device_2 =
        device_fixture(realm,
          device_id: "nWwr7SZiR8CgZN_uKHsAJg",
          part_number: system_model_part_number_2
        )

      filters = %{system_model_name: "fo"}

      assert Devices.list_devices(filters) == [device_1]
    end

    test "list_devices/1 filters with hardware_type_part_number", %{realm: realm} do
      hardware_type_1 =
        hardware_type_fixture(name: "HW1", handle: "hw1", part_numbers: ["AAA-BBB"])

      system_model_part_number_1 = "XYZ/1234"

      _system_model_1 =
        system_model_fixture(
          hardware_type: hardware_type_1,
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      hardware_type_2 =
        hardware_type_fixture(name: "HW2", handle: "hw2", part_numbers: ["CCC-DDD"])

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(
          hardware_type: hardware_type_2,
          name: "Bar",
          handle: "bar",
          part_numbers: [system_model_part_number_2]
        )

      device_1 =
        device_fixture(realm,
          device_id: "7mcE8JeZQkSzjLyYuh5N9A",
          part_number: system_model_part_number_1
        )

      _device_2 =
        device_fixture(realm,
          device_id: "nWwr7SZiR8CgZN_uKHsAJg",
          part_number: system_model_part_number_2
        )

      filters = %{hardware_type_part_number: "AAA"}

      assert Devices.list_devices(filters) == [device_1]
    end

    test "list_devices/1 filters with hardware_type_name", %{realm: realm} do
      hardware_type_1 =
        hardware_type_fixture(name: "HW1", handle: "hw1", part_numbers: ["AAA-BBB"])

      system_model_part_number_1 = "XYZ/1234"

      _system_model_1 =
        system_model_fixture(
          hardware_type: hardware_type_1,
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      hardware_type_2 =
        hardware_type_fixture(name: "HW2", handle: "hw2", part_numbers: ["CCC-DDD"])

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(
          hardware_type: hardware_type_2,
          name: "Bar",
          handle: "bar",
          part_numbers: [system_model_part_number_2]
        )

      device_1 =
        device_fixture(realm,
          device_id: "7mcE8JeZQkSzjLyYuh5N9A",
          part_number: system_model_part_number_1
        )

      _device_2 =
        device_fixture(realm,
          device_id: "nWwr7SZiR8CgZN_uKHsAJg",
          part_number: system_model_part_number_2
        )

      filters = %{hardware_type_name: "HW1"}

      assert Devices.list_devices(filters) == [device_1]
    end

    test "list_devices/1 filters with hardware_type_handle", %{realm: realm} do
      hardware_type_1 =
        hardware_type_fixture(name: "HW1", handle: "hw1", part_numbers: ["AAA-BBB"])

      system_model_part_number_1 = "XYZ/1234"

      _system_model_1 =
        system_model_fixture(
          hardware_type: hardware_type_1,
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      hardware_type_2 =
        hardware_type_fixture(name: "HW2", handle: "hw2", part_numbers: ["CCC-DDD"])

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(
          hardware_type: hardware_type_2,
          name: "Bar",
          handle: "bar",
          part_numbers: [system_model_part_number_2]
        )

      device_1 =
        device_fixture(realm,
          device_id: "7mcE8JeZQkSzjLyYuh5N9A",
          part_number: system_model_part_number_1
        )

      _device_2 =
        device_fixture(realm,
          device_id: "nWwr7SZiR8CgZN_uKHsAJg",
          part_number: system_model_part_number_2
        )

      filters = %{hardware_type_handle: "1"}

      assert Devices.list_devices(filters) == [device_1]
    end

    test "list_devices/1 filters with tag", %{realm: realm} do
      device_1 = device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A")
      update_attrs_1 = %{tags: ["custom", "customer"]}
      assert {:ok, %Device{} = device_1} = Devices.update_device(device_1, update_attrs_1)

      device_2 = device_fixture(realm, device_id: "nWwr7SZiR8CgZN_uKHsAJg")
      update_attrs_2 = %{tags: ["other"]}
      assert {:ok, _device2} = Devices.update_device(device_2, update_attrs_2)

      filters = %{tag: "custom"}
      assert Devices.list_devices(filters) == [device_1]
    end

    test "list_devices/1 combines filters with AND", %{realm: realm} do
      device_1 = device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A", online: true)
      _device_2 = device_fixture(realm, device_id: "nWwr7SZiR8CgZN_uKHsAJg", online: false)
      _device_3 = device_fixture(realm, device_id: "fsMoT420Ri-zXLjxXK6pEg", online: true)
      filters = %{device_id: "7", online: true}

      assert Devices.list_devices(filters) == [device_1]
    end

    test "list_devices/1 returns empty list for system model filters if the device does not have a system model",
         %{realm: realm} do
      _device = device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A", online: true)
      filters = %{system_model_name: "foo"}

      assert Devices.list_devices(filters) == []
    end

    test "list_devices/1 returns empty list for hardware type filters if the device does not have a system model",
         %{realm: realm} do
      _device = device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A", online: true)
      filters = %{hardware_type_handle: "bar"}

      assert Devices.list_devices(filters) == []
    end

    test "get_device!/1 returns the device with given id", %{realm: realm} do
      device = device_fixture(realm)
      assert Devices.get_device!(device.id) == device
    end

    test "update_device/2 with valid data updates the device", %{realm: realm} do
      device = device_fixture(realm)

      update_attrs = %{
        name: "some updated name",
        tags: ["some", "tags"],
        custom_attributes: [
          %{
            "namespace" => "custom",
            "key" => "some-attribute",
            "typed_value" => %{"type" => "double", "value" => 42}
          }
        ]
      }

      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert device.name == "some updated name"
      assert ["some", "tags"] == Enum.map(device.tags, & &1.name)
      assert [custom_attribute] = device.custom_attributes

      assert %Labeling.DeviceAttribute{
               namespace: :custom,
               key: "some-attribute",
               typed_value: %Ecto.JSONVariant{type: :double, value: 42.0}
             } = custom_attribute
    end

    test "update_device/2 normalizes and deduplicates tags", %{realm: realm} do
      device = device_fixture(realm)
      update_attrs = %{tags: ["sTRANGE", "taGs   ", "  DUPlicate", "DUPLICATE"]}
      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)

      assert ["strange", "tags", "duplicate"] == Enum.map(device.tags, & &1.name)
    end

    test "update_device/2 removes tags", %{realm: realm} do
      device = device_fixture(realm)
      update_attrs = %{tags: ["some", "tags"]}

      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert ["some", "tags"] == Enum.map(device.tags, & &1.name)

      update_attrs = %{tags: ["new"]}
      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert ["new"] == Enum.map(device.tags, & &1.name)
    end

    test "update_device/2 adds tags", %{realm: realm} do
      device = device_fixture(realm)
      update_attrs = %{tags: ["some", "tags"]}

      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert ["some", "tags"] == Enum.map(device.tags, & &1.name)

      update_attrs = %{tags: ["some", "tags", "new"]}
      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert ["some", "tags", "new"] == Enum.map(device.tags, & &1.name)
    end

    test "update_device/2 returns an error for invalid tags", %{realm: realm} do
      device = device_fixture(realm)
      update_attrs = %{tags: "not a list"}
      assert {:error, %Ecto.Changeset{}} = Devices.update_device(device, update_attrs)
    end

    test "update_device/2 does not update the device_id", %{realm: realm} do
      device = device_fixture(realm)
      initial_device_id = device.device_id
      update_attrs = %{device_id: "some updated device_id"}

      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert device.device_id == initial_device_id
    end

    test "update_device/2 adds custom attributes", %{realm: realm} do
      device = device_fixture(realm)

      update_attrs = %{
        custom_attributes: [
          %{
            "namespace" => "custom",
            "key" => "some-attribute",
            "typed_value" => %{"type" => "double", "value" => 42}
          }
        ]
      }

      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert [custom_attribute] = device.custom_attributes

      assert %Labeling.DeviceAttribute{
               namespace: :custom,
               key: "some-attribute",
               typed_value: %Ecto.JSONVariant{type: :double, value: 42.0}
             } = custom_attribute

      update_attrs = %{
        custom_attributes: [
          %{
            "namespace" => "custom",
            "key" => "some-attribute",
            "typed_value" => %{"type" => "double", "value" => 42}
          },
          %{
            "namespace" => "custom",
            "key" => "some-other-attribute",
            "typed_value" => %{"type" => "string", "value" => "hello"}
          }
        ]
      }

      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert [^custom_attribute, new_attribute] = device.custom_attributes

      assert %Labeling.DeviceAttribute{
               namespace: :custom,
               key: "some-other-attribute",
               typed_value: %Ecto.JSONVariant{type: :string, value: "hello"}
             } = new_attribute
    end

    test "update_device/2 removes custom attributes", %{realm: realm} do
      device = device_fixture(realm)

      update_attrs = %{
        custom_attributes: [
          %{
            "namespace" => "custom",
            "key" => "some-attribute",
            "typed_value" => %{"type" => "double", "value" => 42}
          },
          %{
            "namespace" => "custom",
            "key" => "some-other-attribute",
            "typed_value" => %{"type" => "string", "value" => "hello"}
          }
        ]
      }

      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert [attribute_1, _attribute_2] = device.custom_attributes

      update_attrs = %{
        custom_attributes: [
          %{
            "namespace" => "custom",
            "key" => "some-attribute",
            "typed_value" => %{"type" => "double", "value" => 42}
          }
        ]
      }

      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert [^attribute_1] = device.custom_attributes
    end

    test "update_device/2 updates custom attributes", %{realm: realm} do
      device = device_fixture(realm)

      update_attrs = %{
        custom_attributes: [
          %{
            "namespace" => "custom",
            "key" => "some-attribute",
            "typed_value" => %{"type" => "double", "value" => 42}
          }
        ]
      }

      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)
      assert [custom_attribute] = device.custom_attributes

      assert %Labeling.DeviceAttribute{
               namespace: :custom,
               key: "some-attribute",
               typed_value: %Ecto.JSONVariant{type: :double, value: 42.0}
             } = custom_attribute

      update_attrs = %{
        custom_attributes: [
          %{
            "namespace" => "custom",
            "key" => "some-attribute",
            "typed_value" => %{"type" => "string", "value" => "new value"}
          }
        ]
      }

      assert {:ok, %Device{} = device} = Devices.update_device(device, update_attrs)

      assert [updated_attribute] = device.custom_attributes

      assert %Labeling.DeviceAttribute{
               namespace: :custom,
               key: "some-attribute",
               typed_value: %Ecto.JSONVariant{type: :string, value: "new value"}
             } = updated_attribute
    end

    test "update_device/2 with invalid data returns error changeset", %{realm: realm} do
      device = device_fixture(realm)
      assert {:error, %Ecto.Changeset{}} = Devices.update_device(device, @invalid_attrs)
      assert device == Devices.get_device!(device.id)
    end

    test "delete_device/1 deletes the device", %{realm: realm} do
      device = device_fixture(realm)
      assert {:ok, %Device{}} = Devices.delete_device(device)
      assert_raise Ecto.NoResultsError, fn -> Devices.get_device!(device.id) end
    end

    test "change_device/1 returns a device changeset", %{realm: realm} do
      device = device_fixture(realm)
      assert %Ecto.Changeset{} = Devices.change_device(device)
    end
  end
end
