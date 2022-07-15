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

    import Edgehog.GroupsFixtures

    @invalid_attrs %{handle: nil, name: nil, selector: nil}

    test "list_device_groups/0 returns all device_groups" do
      device_group = device_group_fixture()
      assert Groups.list_device_groups() == [device_group]
    end

    test "get_device_group!/1 returns the device_group with given id" do
      device_group = device_group_fixture()
      assert Groups.get_device_group!(device_group.id) == device_group
    end

    test "create_device_group/1 with valid data creates a device_group" do
      valid_attrs = %{handle: "some handle", name: "some name", selector: "some selector"}

      assert {:ok, %DeviceGroup{} = device_group} = Groups.create_device_group(valid_attrs)
      assert device_group.handle == "some handle"
      assert device_group.name == "some name"
      assert device_group.selector == "some selector"
    end

    test "create_device_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Groups.create_device_group(@invalid_attrs)
    end

    test "update_device_group/2 with valid data updates the device_group" do
      device_group = device_group_fixture()

      update_attrs = %{
        handle: "some updated handle",
        name: "some updated name",
        selector: "some updated selector"
      }

      assert {:ok, %DeviceGroup{} = device_group} =
               Groups.update_device_group(device_group, update_attrs)

      assert device_group.handle == "some updated handle"
      assert device_group.name == "some updated name"
      assert device_group.selector == "some updated selector"
    end

    test "update_device_group/2 with invalid data returns error changeset" do
      device_group = device_group_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Groups.update_device_group(device_group, @invalid_attrs)

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
