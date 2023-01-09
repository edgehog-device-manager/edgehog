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
  use Edgehog.DataCase

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
      hardware_type = hardware_type_fixture()

      system_model_part_number_1 = "XYZ/1234"

      _system_model_1 =
        system_model_fixture(hardware_type,
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(hardware_type,
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
      hardware_type = hardware_type_fixture()

      system_model_part_number_1 = "XYZ/1234"

      _system_model_1 =
        system_model_fixture(hardware_type,
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(hardware_type,
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
      hardware_type = hardware_type_fixture()

      system_model_part_number_1 = "XYZ/1234"

      _system_model_1 =
        system_model_fixture(hardware_type,
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(hardware_type,
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
        system_model_fixture(hardware_type_1,
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      hardware_type_2 =
        hardware_type_fixture(name: "HW2", handle: "hw2", part_numbers: ["CCC-DDD"])

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(hardware_type_2,
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
        system_model_fixture(hardware_type_1,
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      hardware_type_2 =
        hardware_type_fixture(name: "HW2", handle: "hw2", part_numbers: ["CCC-DDD"])

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(hardware_type_2,
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
        system_model_fixture(hardware_type_1,
          name: "Foo",
          handle: "foo",
          part_numbers: [system_model_part_number_1]
        )

      hardware_type_2 =
        hardware_type_fixture(name: "HW2", handle: "hw2", part_numbers: ["CCC-DDD"])

      system_model_part_number_2 = "ABC/0987"

      _system_model_2 =
        system_model_fixture(hardware_type_2,
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

      filters = %{hardware_type_name: "1"}

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

  describe "hardware_types" do
    alias Edgehog.Devices.HardwareType
    alias Edgehog.Devices.HardwareTypePartNumber

    import Edgehog.DevicesFixtures

    @invalid_attrs %{handle: nil, name: nil, part_numbers: []}

    test "list_hardware_types/0 returns all hardware_types" do
      hardware_type = hardware_type_fixture()
      assert Devices.list_hardware_types() == [hardware_type]
    end

    test "fetch_hardware_type/1 returns the hardware_type with given id" do
      hardware_type = hardware_type_fixture()
      assert Devices.fetch_hardware_type(hardware_type.id) == {:ok, hardware_type}
    end

    test "create_hardware_type/1 with valid data creates a hardware_type" do
      valid_attrs = %{handle: "some-handle", name: "some name", part_numbers: ["ABC123"]}

      assert {:ok, %HardwareType{} = hardware_type} = Devices.create_hardware_type(valid_attrs)
      assert hardware_type.handle == "some-handle"
      assert hardware_type.name == "some name"
      assert [%HardwareTypePartNumber{part_number: "ABC123"}] = hardware_type.part_numbers
    end

    test "create_hardware_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Devices.create_hardware_type(@invalid_attrs)
    end

    test "update_hardware_type/2 with valid data updates the hardware_type" do
      hardware_type = hardware_type_fixture()

      update_attrs = %{
        handle: "some-updated-handle",
        name: "some updated name",
        part_numbers: ["DEF456"]
      }

      assert {:ok, %HardwareType{} = hardware_type} =
               Devices.update_hardware_type(hardware_type, update_attrs)

      assert hardware_type.handle == "some-updated-handle"
      assert hardware_type.name == "some updated name"
      assert [%HardwareTypePartNumber{part_number: "DEF456"}] = hardware_type.part_numbers
    end

    test "update_hardware_type/2 with invalid data returns error changeset" do
      hardware_type = hardware_type_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Devices.update_hardware_type(hardware_type, @invalid_attrs)

      assert {:ok, hardware_type} == Devices.fetch_hardware_type(hardware_type.id)
    end

    test "delete_hardware_type/1 deletes the hardware_type" do
      hardware_type = hardware_type_fixture()
      assert {:ok, %HardwareType{}} = Devices.delete_hardware_type(hardware_type)
      assert {:error, :not_found} == Devices.fetch_hardware_type(hardware_type.id)
    end

    test "delete_hardware_type/1 returns error changeset for hardware_type in use" do
      hardware_type = hardware_type_fixture()
      _system_model = system_model_fixture(hardware_type)

      assert {:error, %Ecto.Changeset{}} = Devices.delete_hardware_type(hardware_type)
      assert {:ok, hardware_type} == Devices.fetch_hardware_type(hardware_type.id)
    end

    test "change_hardware_type/1 returns a hardware_type changeset" do
      hardware_type = hardware_type_fixture()
      assert %Ecto.Changeset{} = Devices.change_hardware_type(hardware_type)
    end

    test "create_hardware_type/1 with invalid handle returns error changeset" do
      attrs = %{handle: "INVALID HANDLE !", name: "some name", part_numbers: ["ABC123"]}

      assert {:error, %Ecto.Changeset{}} = Devices.create_hardware_type(attrs)
    end
  end

  describe "system_models" do
    alias Edgehog.Devices.SystemModel
    alias Edgehog.Devices.SystemModelPartNumber

    import Edgehog.AstarteFixtures, except: [device_fixture: 1, device_fixture: 2]
    import Edgehog.DevicesFixtures

    setup do
      hardware_type = hardware_type_fixture()

      {:ok, hardware_type: hardware_type}
    end

    @invalid_attrs %{handle: nil, name: nil, part_numbers: []}

    test "list_system_models/0 returns all system_models", %{hardware_type: hardware_type} do
      system_model = system_model_fixture(hardware_type)
      assert Devices.list_system_models() == [system_model]
    end

    test "fetch_system_model/1 returns the system_model with given id", %{
      hardware_type: hardware_type
    } do
      system_model = system_model_fixture(hardware_type)
      assert Devices.fetch_system_model(system_model.id) == {:ok, system_model}
    end

    test "create_system_model/1 with valid data creates a system_model", %{
      hardware_type: hardware_type
    } do
      valid_attrs = %{
        handle: "some-handle",
        name: "some name",
        part_numbers: ["1234-rev4"]
      }

      assert {:ok, %SystemModel{} = system_model} =
               Devices.create_system_model(hardware_type, valid_attrs)

      assert system_model.handle == "some-handle"
      assert system_model.name == "some name"
      assert [%SystemModelPartNumber{part_number: "1234-rev4"}] = system_model.part_numbers
    end

    test "create_system_model/1 associates system_model with devices having same part_number", %{
      hardware_type: hardware_type
    } do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      part_number_1 = "1234-rev5"
      part_number_2 = "1234-rev6"

      device_1 =
        device_fixture(realm, part_number: part_number_1)
        |> Devices.preload_system_model()

      device_2 =
        device_fixture(realm, part_number: part_number_2)
        |> Devices.preload_system_model()

      device_3 =
        device_fixture(realm, part_number: "4321-rev1")
        |> Devices.preload_system_model()

      assert device_1.system_model == nil
      assert device_2.system_model == nil
      assert device_3.system_model == nil

      attrs = %{
        handle: "some-handle",
        name: "some name",
        part_numbers: [part_number_1, part_number_2]
      }

      assert {:ok, %SystemModel{} = system_model} =
               Devices.create_system_model(hardware_type, attrs)

      preload = [hardware_type: [], part_numbers: []]
      device_1 = Devices.preload_system_model(device_1, force: true, preload: preload)
      device_2 = Devices.preload_system_model(device_2, force: true, preload: preload)
      device_3 = Devices.preload_system_model(device_3, force: true, preload: preload)

      assert device_1.system_model == system_model
      assert device_2.system_model == system_model
      assert device_3.system_model == nil
    end

    test "create_system_model/1 saves descriptions", %{hardware_type: hardware_type} do
      valid_attrs = %{
        handle: "some-handle",
        name: "some name",
        part_numbers: ["1234-rev4"],
        description: %{"en-US" => "Yadda"}
      }

      assert {:ok, %SystemModel{} = system_model} =
               Devices.create_system_model(hardware_type, valid_attrs)

      assert %{"en-US" => "Yadda"} = system_model.description
    end

    test "create_system_model/1 with invalid data returns error changeset", %{
      hardware_type: hardware_type
    } do
      assert {:error, %Ecto.Changeset{}} =
               Devices.create_system_model(hardware_type, @invalid_attrs)
    end

    test "create_system_model/1 with invalid description returns error changeset", %{
      hardware_type: hardware_type
    } do
      attrs = %{
        handle: "some-handle",
        name: "some name",
        part_numbers: ["1234-rev4"],
        description: %{"INVALID_loc4le" => "Yadda"}
      }

      assert {:error, %Ecto.Changeset{}} = Devices.create_system_model(hardware_type, attrs)
    end

    test "create_system_model/1 with invalid handle returns error changeset", %{
      hardware_type: hardware_type
    } do
      attrs = %{handle: "INVALID HANDLE++", name: "some name"}

      assert {:error, %Ecto.Changeset{}} = Devices.create_system_model(hardware_type, attrs)
    end

    test "create_system_model/1 with duplicate handle returns error changeset", %{
      hardware_type: hardware_type
    } do
      system_model = system_model_fixture(hardware_type)
      attrs = %{handle: system_model.handle, name: "some other name"}

      assert {:error, %Ecto.Changeset{}} = Devices.create_system_model(hardware_type, attrs)
    end

    test "create_system_model/1 with duplicate name returns error changeset", %{
      hardware_type: hardware_type
    } do
      system_model = system_model_fixture(hardware_type)
      attrs = %{handle: "some-other-handle", name: system_model.name}

      assert {:error, %Ecto.Changeset{}} = Devices.create_system_model(hardware_type, attrs)
    end

    test "update_system_model/2 with valid data updates the system_model", %{
      hardware_type: hardware_type
    } do
      system_model =
        system_model_fixture(hardware_type,
          description: %{"en-US" => "Yadda"}
        )

      update_attrs = %{
        handle: "some-updated-handle",
        name: "some updated name",
        part_numbers: ["1234-rev5"],
        description: %{"en-US" => "Yadda yadda"}
      }

      assert {:ok, %SystemModel{} = system_model} =
               Devices.update_system_model(system_model, update_attrs)

      assert system_model.handle == "some-updated-handle"
      assert system_model.name == "some updated name"
      assert [%SystemModelPartNumber{part_number: "1234-rev5"}] = system_model.part_numbers

      assert %{"en-US" => "Yadda yadda"} = system_model.description
    end

    test "update_system_model/2 with invalid data returns error changeset", %{
      hardware_type: hardware_type
    } do
      system_model = system_model_fixture(hardware_type)

      assert {:error, %Ecto.Changeset{}} =
               Devices.update_system_model(system_model, @invalid_attrs)

      assert {:ok, system_model} == Devices.fetch_system_model(system_model.id)
    end

    test "delete_system_model/1 deletes the system_model", %{hardware_type: hardware_type} do
      system_model = system_model_fixture(hardware_type)
      assert {:ok, %SystemModel{}} = Devices.delete_system_model(system_model)

      assert Devices.fetch_system_model(system_model.id) == {:error, :not_found}
    end

    test "delete_system_model/1 deletes the system_model in use", %{hardware_type: hardware_type} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)
      part_number = "1234-rev4"

      system_model = system_model_fixture(hardware_type, part_numbers: [part_number])

      device =
        realm
        |> device_fixture(part_number: part_number)
        |> Devices.preload_system_model(
          force: true,
          preload: [hardware_type: [], part_numbers: []]
        )

      assert device.system_model == system_model

      assert {:ok, %SystemModel{}} = Devices.delete_system_model(system_model)
      assert Devices.fetch_system_model(system_model.id) == {:error, :not_found}

      device = Devices.preload_system_model(device, force: true)
      assert device.system_model == nil
      assert device.part_number == part_number
    end

    test "change_system_model/1 returns a system_model changeset", %{
      hardware_type: hardware_type
    } do
      system_model = system_model_fixture(hardware_type)
      assert %Ecto.Changeset{} = Devices.change_system_model(system_model)
    end
  end
end
