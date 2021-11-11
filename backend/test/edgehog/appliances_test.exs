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

  describe "appliance_models" do
    alias Edgehog.Appliances.ApplianceModel
    alias Edgehog.Appliances.ApplianceModelPartNumber

    import Edgehog.AppliancesFixtures

    setup do
      hardware_type = hardware_type_fixture()

      {:ok, hardware_type: hardware_type}
    end

    @invalid_attrs %{handle: nil, name: nil, part_numbers: []}

    test "list_appliance_models/0 returns all appliance_models", %{hardware_type: hardware_type} do
      appliance_model = appliance_model_fixture(hardware_type)
      assert Appliances.list_appliance_models() == [appliance_model]
    end

    test "get_appliance_model!/1 returns the appliance_model with given id", %{
      hardware_type: hardware_type
    } do
      appliance_model = appliance_model_fixture(hardware_type)
      assert Appliances.get_appliance_model!(appliance_model.id) == appliance_model
    end

    test "create_appliance_model/1 with valid data creates a appliance_model", %{
      hardware_type: hardware_type
    } do
      valid_attrs = %{
        handle: "some-handle",
        name: "some name",
        part_numbers: ["1234-rev4"]
      }

      assert {:ok, %ApplianceModel{} = appliance_model} =
               Appliances.create_appliance_model(hardware_type, valid_attrs)

      assert appliance_model.handle == "some-handle"
      assert appliance_model.name == "some name"
      assert [%ApplianceModelPartNumber{part_number: "1234-rev4"}] = appliance_model.part_numbers
    end

    test "create_appliance_model/1 with invalid data returns error changeset", %{
      hardware_type: hardware_type
    } do
      assert {:error, %Ecto.Changeset{}} =
               Appliances.create_appliance_model(hardware_type, @invalid_attrs)
    end

    test "create_appliance_model/1 with invalid handle returns error changeset", %{
      hardware_type: hardware_type
    } do
      attrs = %{handle: "INVALID HANDLE++", name: "some name"}

      assert {:error, %Ecto.Changeset{}} = Appliances.create_appliance_model(hardware_type, attrs)
    end

    test "create_appliance_model/1 with duplicate handle returns error changeset", %{
      hardware_type: hardware_type
    } do
      appliance_model = appliance_model_fixture(hardware_type)
      attrs = %{handle: appliance_model.handle, name: "some other name"}

      assert {:error, %Ecto.Changeset{}} = Appliances.create_appliance_model(hardware_type, attrs)
    end

    test "create_appliance_model/1 with duplicate name returns error changeset", %{
      hardware_type: hardware_type
    } do
      appliance_model = appliance_model_fixture(hardware_type)
      attrs = %{handle: "some-other-handle", name: appliance_model.name}

      assert {:error, %Ecto.Changeset{}} = Appliances.create_appliance_model(hardware_type, attrs)
    end

    test "update_appliance_model/2 with valid data updates the appliance_model", %{
      hardware_type: hardware_type
    } do
      appliance_model = appliance_model_fixture(hardware_type)

      update_attrs = %{
        handle: "some-updated-handle",
        name: "some updated name",
        part_numbers: ["1234-rev5"]
      }

      assert {:ok, %ApplianceModel{} = appliance_model} =
               Appliances.update_appliance_model(appliance_model, update_attrs)

      assert appliance_model.handle == "some-updated-handle"
      assert appliance_model.name == "some updated name"
      assert [%ApplianceModelPartNumber{part_number: "1234-rev5"}] = appliance_model.part_numbers
    end

    test "update_appliance_model/2 with invalid data returns error changeset", %{
      hardware_type: hardware_type
    } do
      appliance_model = appliance_model_fixture(hardware_type)

      assert {:error, %Ecto.Changeset{}} =
               Appliances.update_appliance_model(appliance_model, @invalid_attrs)

      assert appliance_model == Appliances.get_appliance_model!(appliance_model.id)
    end

    test "delete_appliance_model/1 deletes the appliance_model", %{hardware_type: hardware_type} do
      appliance_model = appliance_model_fixture(hardware_type)
      assert {:ok, %ApplianceModel{}} = Appliances.delete_appliance_model(appliance_model)

      assert_raise Ecto.NoResultsError, fn ->
        Appliances.get_appliance_model!(appliance_model.id)
      end
    end

    test "change_appliance_model/1 returns a appliance_model changeset", %{
      hardware_type: hardware_type
    } do
      appliance_model = appliance_model_fixture(hardware_type)
      assert %Ecto.Changeset{} = Appliances.change_appliance_model(appliance_model)
    end
  end
end
