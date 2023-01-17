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

defmodule Edgehog.BaseImagesTest do
  use Edgehog.DataCase

  alias Edgehog.BaseImages

  describe "base_image_collections" do
    alias Edgehog.BaseImages.BaseImageCollection

    import Edgehog.BaseImagesFixtures
    import Edgehog.DevicesFixtures

    setup do
      hardware_type = hardware_type_fixture()

      {:ok, system_model: system_model_fixture(hardware_type)}
    end

    @invalid_attrs %{handle: "3 invalid handle", name: ""}

    test "list_base_image_collections/0 returns all base_image_collections", %{
      system_model: system_model
    } do
      base_image_collection = base_image_collection_fixture(system_model)
      assert BaseImages.list_base_image_collections() == [base_image_collection]
    end

    test "fetch_base_image_collection/1 returns the base_image_collection with given id", %{
      system_model: system_model
    } do
      base_image_collection = base_image_collection_fixture(system_model)

      assert BaseImages.fetch_base_image_collection(base_image_collection.id) ==
               {:ok, base_image_collection}
    end

    test "create_base_image_collection/2 with valid data creates a base_image_collection", %{
      system_model: system_model
    } do
      valid_attrs = %{handle: "some-handle", name: "some name"}

      assert {:ok, %BaseImageCollection{} = base_image_collection} =
               BaseImages.create_base_image_collection(system_model, valid_attrs)

      assert base_image_collection.handle == "some-handle"
      assert base_image_collection.name == "some name"
    end

    test "create_base_image_collection/2 with invalid data returns error changeset", %{
      system_model: system_model
    } do
      assert {:error, %Ecto.Changeset{}} =
               BaseImages.create_base_image_collection(system_model, @invalid_attrs)
    end

    test "update_base_image_collection/2 with valid data updates the base_image_collection", %{
      system_model: system_model
    } do
      base_image_collection = base_image_collection_fixture(system_model)
      update_attrs = %{handle: "some-updated-handle", name: "some updated name"}

      assert {:ok, %BaseImageCollection{} = base_image_collection} =
               BaseImages.update_base_image_collection(base_image_collection, update_attrs)

      assert base_image_collection.handle == "some-updated-handle"
      assert base_image_collection.name == "some updated name"
    end

    test "update_base_image_collection/2 with invalid data returns error changeset", %{
      system_model: system_model
    } do
      base_image_collection = base_image_collection_fixture(system_model)

      assert {:error, %Ecto.Changeset{}} =
               BaseImages.update_base_image_collection(base_image_collection, @invalid_attrs)

      assert {:ok, base_image_collection} ==
               BaseImages.fetch_base_image_collection(base_image_collection.id)
    end

    test "delete_base_image_collection/1 deletes the base_image_collection", %{
      system_model: system_model
    } do
      base_image_collection = base_image_collection_fixture(system_model)

      assert {:ok, %BaseImageCollection{}} =
               BaseImages.delete_base_image_collection(base_image_collection)

      assert {:error, :not_found} ==
               BaseImages.fetch_base_image_collection(base_image_collection.id)
    end

    test "change_base_image_collection/1 returns a base_image_collection changeset", %{
      system_model: system_model
    } do
      base_image_collection = base_image_collection_fixture(system_model)
      assert %Ecto.Changeset{} = BaseImages.change_base_image_collection(base_image_collection)
    end
  end

  describe "base_images" do
    alias Edgehog.BaseImages.BaseImage

    import Edgehog.BaseImagesFixtures

    @invalid_attrs %{
      description: nil,
      release_display_name: nil,
      starting_version_requirement: nil,
      version: nil
    }

    test "list_base_images/0 returns all base_images" do
      base_image = base_image_fixture()
      assert BaseImages.list_base_images() == [base_image]
    end

    test "get_base_image!/1 returns the base_image with given id" do
      base_image = base_image_fixture()
      assert BaseImages.get_base_image!(base_image.id) == base_image
    end

    test "create_base_image/1 with valid data creates a base_image" do
      valid_attrs = %{
        description: %{},
        release_display_name: %{},
        starting_version_requirement: "some starting_version_requirement",
        version: "some version"
      }

      assert {:ok, %BaseImage{} = base_image} = BaseImages.create_base_image(valid_attrs)
      assert base_image.description == %{}
      assert base_image.release_display_name == %{}
      assert base_image.starting_version_requirement == "some starting_version_requirement"
      assert base_image.version == "some version"
    end

    test "create_base_image/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = BaseImages.create_base_image(@invalid_attrs)
    end

    test "update_base_image/2 with valid data updates the base_image" do
      base_image = base_image_fixture()

      update_attrs = %{
        description: %{},
        release_display_name: %{},
        starting_version_requirement: "some updated starting_version_requirement",
        version: "some updated version"
      }

      assert {:ok, %BaseImage{} = base_image} =
               BaseImages.update_base_image(base_image, update_attrs)

      assert base_image.description == %{}
      assert base_image.release_display_name == %{}
      assert base_image.starting_version_requirement == "some updated starting_version_requirement"
      assert base_image.version == "some updated version"
    end

    test "update_base_image/2 with invalid data returns error changeset" do
      base_image = base_image_fixture()

      assert {:error, %Ecto.Changeset{}} =
               BaseImages.update_base_image(base_image, @invalid_attrs)

      assert base_image == BaseImages.get_base_image!(base_image.id)
    end

    test "delete_base_image/1 deletes the base_image" do
      base_image = base_image_fixture()
      assert {:ok, %BaseImage{}} = BaseImages.delete_base_image(base_image)
      assert_raise Ecto.NoResultsError, fn -> BaseImages.get_base_image!(base_image.id) end
    end

    test "change_base_image/1 returns a base_image changeset" do
      base_image = base_image_fixture()
      assert %Ecto.Changeset{} = BaseImages.change_base_image(base_image)
    end
  end
end
