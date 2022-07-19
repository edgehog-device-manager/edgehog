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

defmodule Edgehog.GroupsTest do
  use Edgehog.DataCase

  alias Edgehog.Groups

  describe "device_groups" do
    alias Edgehog.Groups.DeviceGroup
    alias Edgehog.Devices

    import Edgehog.AstarteFixtures
    import Edgehog.DevicesFixtures
    import Edgehog.GroupsFixtures

    @invalid_attrs %{handle: nil, name: nil, selector: nil}

    test "list_device_groups/0 returns all device_groups" do
      device_group = device_group_fixture()
      assert Groups.list_device_groups() == [device_group]
    end

    test "list_devices_in_group/0 returns empty list with no devices" do
      device_group = device_group_fixture()
      assert Groups.list_devices_in_group(device_group) == []
    end

    test "list_devices_in_group/0 returns devices matching the group selector" do
      device_group = device_group_fixture(selector: ~s<"foo" in tags>)

      realm =
        cluster_fixture()
        |> realm_fixture()

      {:ok, device_1} =
        device_fixture(realm)
        |> Devices.update_device(%{tags: ["foo", "baz"]})

      {:ok, _device_2} =
        device_fixture(realm, name: "Device 2", device_id: "9FXwmtRtRuqC48DEOjOj7Q")
        |> Devices.update_device(%{tags: ["bar"]})

      assert Groups.list_devices_in_group(device_group) == [device_1]
    end

    test "get_device_group!/1 returns the device_group with given id" do
      device_group = device_group_fixture()
      assert Groups.get_device_group!(device_group.id) == device_group
    end

    test "create_device_group/1 with valid data creates a device_group" do
      valid_attrs = %{handle: "test-devices", name: "Test Devices", selector: ~s<"test" in tags>}

      assert {:ok, %DeviceGroup{} = device_group} = Groups.create_device_group(valid_attrs)
      assert device_group.handle == "test-devices"
      assert device_group.name == "Test Devices"
      assert device_group.selector == ~s<"test" in tags>
    end

    test "create_device_group/1 with empty data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Groups.create_device_group(@invalid_attrs)
    end

    test "create_device_group/1 with invalid handle returns error changeset" do
      attrs = %{handle: "invalid handle", name: "Test Devices", selector: ~s<"test" in tags>}

      assert {:error, %Ecto.Changeset{}} = Groups.create_device_group(attrs)
    end

    test "create_device_group/1 with invalid selector returns error changeset" do
      attrs = %{handle: "test-devices", name: "Test Devices", selector: "invalid selector"}

      assert {:error, %Ecto.Changeset{}} = Groups.create_device_group(attrs)
    end

    test "update_device_group/2 with valid data updates the device_group" do
      device_group = device_group_fixture()

      update_attrs = %{
        handle: "updated-test-devices",
        name: "Updated Test Devices",
        selector: ~s<"test" in tags and attributes["custom:is_updated"] == true>
      }

      assert {:ok, %DeviceGroup{} = device_group} =
               Groups.update_device_group(device_group, update_attrs)

      assert device_group.handle == "updated-test-devices"
      assert device_group.name == "Updated Test Devices"

      assert device_group.selector ==
               ~s<"test" in tags and attributes["custom:is_updated"] == true>
    end

    test "update_device_group/2 with empty data returns error changeset" do
      device_group = device_group_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Groups.update_device_group(device_group, @invalid_attrs)

      assert device_group == Groups.get_device_group!(device_group.id)
    end

    test "update_device_group/1 with invalid handle returns error changeset" do
      device_group = device_group_fixture()

      attrs = %{handle: "invalid updated handle"}

      assert {:error, %Ecto.Changeset{}} = Groups.update_device_group(device_group, attrs)

      assert device_group == Groups.get_device_group!(device_group.id)
    end

    test "update_device_group/1 with invalid selector returns error changeset" do
      device_group = device_group_fixture()

      attrs = %{selector: "invalid updated selector"}

      assert {:error, %Ecto.Changeset{}} = Groups.update_device_group(device_group, attrs)

      assert device_group == Groups.get_device_group!(device_group.id)
    end

    test "delete_device_group/1 deletes the device_group" do
      device_group = device_group_fixture()
      assert {:ok, %DeviceGroup{}} = Groups.delete_device_group(device_group)
      assert_raise Ecto.NoResultsError, fn -> Groups.get_device_group!(device_group.id) end
    end

    test "change_device_group/1 returns a device_group changeset" do
      device_group = device_group_fixture()
      assert %Ecto.Changeset{} = Groups.change_device_group(device_group)
    end
  end
end
