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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.DevicesTest do
  use Edgehog.DataCase

  alias Edgehog.Devices

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
    alias Edgehog.Devices.SystemModelDescription
    alias Edgehog.Devices.SystemModelPartNumber

    import Edgehog.AstarteFixtures
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

    test "create_system_model/1 saves descriptions", %{hardware_type: hardware_type} do
      valid_attrs = %{
        handle: "some-handle",
        name: "some name",
        part_numbers: ["1234-rev4"],
        descriptions: [%{locale: "en-US", text: "Yadda"}]
      }

      assert {:ok, %SystemModel{} = system_model} =
               Devices.create_system_model(hardware_type, valid_attrs)

      assert [%SystemModelDescription{text: "Yadda", locale: "en-US"}] = system_model.descriptions
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
        descriptions: [%{locale: "INVALID_loc4le", text: "Yadda"}]
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
          descriptions: [%{locale: "en-US", text: "Yadda"}]
        )

      update_attrs = %{
        handle: "some-updated-handle",
        name: "some updated name",
        part_numbers: ["1234-rev5"],
        descriptions: [%{locale: "en-US", text: "Yadda yadda"}]
      }

      assert {:ok, %SystemModel{} = system_model} =
               Devices.update_system_model(system_model, update_attrs)

      assert system_model.handle == "some-updated-handle"
      assert system_model.name == "some updated name"
      assert [%SystemModelPartNumber{part_number: "1234-rev5"}] = system_model.part_numbers

      assert [%SystemModelDescription{text: "Yadda yadda"}] = system_model.descriptions
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

    test "delete_system_model/1 returns error changeset for system_model in use", %{
      hardware_type: hardware_type
    } do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)
      part_number = "1234-rev4"
      system_model = system_model_fixture(hardware_type, %{part_numbers: [part_number]})

      _device =
        device_fixture(realm,
          device_id: "7mcE8JeZQkSzjLyYuh5N9A",
          part_number: part_number
        )

      assert {:error, %Ecto.Changeset{}} = Devices.delete_system_model(system_model)
      assert {:ok, system_model} == Devices.fetch_system_model(system_model.id)
    end

    test "change_system_model/1 returns a system_model changeset", %{
      hardware_type: hardware_type
    } do
      system_model = system_model_fixture(hardware_type)
      assert %Ecto.Changeset{} = Devices.change_system_model(system_model)
    end

    test "preload_localized_descriptions_for_system_model/0 returns a localized description for a list",
         %{
           hardware_type: hardware_type
         } do
      descriptions_1 = [
        %{locale: "en-US", text: "A system model"},
        %{locale: "it-IT", text: "Un modello di sistema"}
      ]

      descriptions_2 = [
        %{locale: "en-US", text: "Another system model"}
      ]

      _system_model_1 =
        system_model_fixture(hardware_type,
          name: "SystemModel1",
          handle: "sm1",
          descriptions: descriptions_1
        )

      _system_model_2 =
        system_model_fixture(hardware_type,
          name: "SystemModel2",
          handle: "sm2",
          descriptions: descriptions_2
        )

      assert [system_model_1, system_model_2] =
               Devices.list_system_models()
               |> Devices.preload_localized_descriptions_for_system_model("it-IT")

      assert [%{locale: "it-IT"}] = system_model_1.descriptions
      assert [] = system_model_2.descriptions
    end

    test "preload_localized_descriptions_for_system_model/0 returns a localized description for a single struct",
         %{
           hardware_type: hardware_type
         } do
      descriptions = [
        %{locale: "en-US", text: "A system model"},
        %{locale: "it-IT", text: "Un modello di sistema"}
      ]

      system_model = system_model_fixture(hardware_type, descriptions: descriptions)

      assert {:ok, system_model} = Devices.fetch_system_model(system_model.id)

      system_model =
        Devices.preload_localized_descriptions_for_system_model(system_model, "it-IT")

      assert Enum.map(system_model.descriptions, & &1.locale) == ["it-IT"]
    end
  end
end
