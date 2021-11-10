#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.AppliancesTest do
  use Edgehog.DataCase

  alias Edgehog.Appliances

  describe "hardware_types" do
    alias Edgehog.Appliances.HardwareType
    alias Edgehog.Appliances.HardwareTypePartNumber

    import Edgehog.AppliancesFixtures

    @invalid_attrs %{handle: nil, name: nil, part_numbers: []}

    test "list_hardware_types/0 returns all hardware_types" do
      hardware_type = hardware_type_fixture()
      assert Appliances.list_hardware_types() == [hardware_type]
    end

    test "fetch_hardware_type/1 returns the hardware_type with given id" do
      hardware_type = hardware_type_fixture()
      assert Appliances.fetch_hardware_type(hardware_type.id) == {:ok, hardware_type}
    end

    test "create_hardware_type/1 with valid data creates a hardware_type" do
      valid_attrs = %{handle: "some-handle", name: "some name", part_numbers: ["ABC123"]}

      assert {:ok, %HardwareType{} = hardware_type} = Appliances.create_hardware_type(valid_attrs)
      assert hardware_type.handle == "some-handle"
      assert hardware_type.name == "some name"
      assert [%HardwareTypePartNumber{part_number: "ABC123"}] = hardware_type.part_numbers
    end

    test "create_hardware_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Appliances.create_hardware_type(@invalid_attrs)
    end

    test "update_hardware_type/2 with valid data updates the hardware_type" do
      hardware_type = hardware_type_fixture()

      update_attrs = %{
        handle: "some-updated-handle",
        name: "some updated name",
        part_numbers: ["DEF456"]
      }

      assert {:ok, %HardwareType{} = hardware_type} =
               Appliances.update_hardware_type(hardware_type, update_attrs)

      assert hardware_type.handle == "some-updated-handle"
      assert hardware_type.name == "some updated name"
      assert [%HardwareTypePartNumber{part_number: "DEF456"}] = hardware_type.part_numbers
    end

    test "update_hardware_type/2 with invalid data returns error changeset" do
      hardware_type = hardware_type_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Appliances.update_hardware_type(hardware_type, @invalid_attrs)

      assert {:ok, hardware_type} == Appliances.fetch_hardware_type(hardware_type.id)
    end

    test "delete_hardware_type/1 deletes the hardware_type" do
      hardware_type = hardware_type_fixture()
      assert {:ok, %HardwareType{}} = Appliances.delete_hardware_type(hardware_type)
      assert {:error, :not_found} == Appliances.fetch_hardware_type(hardware_type.id)
    end

    test "change_hardware_type/1 returns a hardware_type changeset" do
      hardware_type = hardware_type_fixture()
      assert %Ecto.Changeset{} = Appliances.change_hardware_type(hardware_type)
    end

    test "create_hardware_type/1 with invalid handle returns error changeset" do
      attrs = %{handle: "INVALID HANDLE !", name: "some name", part_numbers: ["ABC123"]}

      assert {:error, %Ecto.Changeset{}} = Appliances.create_hardware_type(attrs)
    end
  end
end
