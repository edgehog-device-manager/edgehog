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

defmodule Edgehog.BaseImagesTest do
  use Edgehog.DataCase
  use Edgehog.BaseImagesStorageMockCase

  alias Edgehog.BaseImages
  alias Edgehog.BaseImages.StorageMock
  alias Edgehog.Mocks
  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures

  describe "base_image_collections" do
    alias Edgehog.BaseImages.BaseImageCollection

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

    test "list_base_images/0 returns all base_images" do
      base_image = base_image_fixture()
      assert BaseImages.list_base_images() == [base_image]
    end

    test "list_base_images_for_collection/0 returns only base_images that belong to the collection" do
      base_image_collection_1 = create_base_image_collection!()
      base_image_fixture(base_image_collection: base_image_collection_1)

      base_image_collection_2 = create_base_image_collection!()
      base_image_2 = base_image_fixture(base_image_collection: base_image_collection_2)

      assert BaseImages.list_base_images_for_collection(base_image_collection_2) == [base_image_2]
    end

    test "fetch_base_image/1 returns the base_image with given id" do
      base_image = base_image_fixture()
      assert {:ok, base_image} == BaseImages.fetch_base_image(base_image.id)
    end

    test "create_base_image/1 with valid data creates a base_image" do
      base_image_collection = create_base_image_collection!()

      attrs = %{
        description: %{"en-US" => "A feature packed release"},
        release_display_name: %{"en-US" => "Happy Hyena"},
        starting_version_requirement: "~> 1.0",
        version: "1.4.0",
        file: %Plug.Upload{path: "/tmp/ota.bin", filename: "ota.bin"}
      }

      assert {:ok, %BaseImage{} = base_image} =
               BaseImages.create_base_image(base_image_collection, attrs)

      assert base_image.description == %{"en-US" => "A feature packed release"}
      assert base_image.release_display_name == %{"en-US" => "Happy Hyena"}
      assert base_image.starting_version_requirement == "~> 1.0"
      assert base_image.version == "1.4.0"
    end

    test "create_base_image/1 with valid data uploads the base image to the storage" do
      expect(StorageMock, :store, &Mocks.BaseImages.Storage.store/2)
      assert {:ok, _} = create_base_image()
    end

    test "create_base_image/1 fails if the upload to the storage fails" do
      expect(StorageMock, :store, fn _, _ -> {:error, :bucket_is_full} end)
      assert {:error, :bucket_is_full} = create_base_image()
    end

    test "create_base_image/1 with same version for the different base image collections succeeds" do
      collection_1 = create_base_image_collection!()
      base_image_fixture(base_image_collection: collection_1, version: "1.3.0")

      collection_2 = create_base_image_collection!()

      assert {:ok, %BaseImage{}} =
               create_base_image(base_image_collection: collection_2, version: "1.3.0")
    end

    test "create_base_image/1 with invalid version returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = create_base_image(version: "foobaz")

      assert "is not a valid version" in errors_on(changeset).version
    end

    test "create_base_image/1 with invalid description locale returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_base_image(description: %{"notAlocale" => "baz"})

      assert "notAlocale is not a valid locale" in errors_on(changeset).description
    end

    test "create_base_image/1 with invalid release display name locale returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_base_image(release_display_name: %{"notAlocale" => "baz"})

      assert "notAlocale is not a valid locale" in errors_on(changeset).release_display_name
    end

    test "create_base_image/1 with invalid supported starting version returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_base_image(starting_version_requirement: "invalid")

      assert "is not a valid version requirement" in errors_on(changeset).starting_version_requirement
    end

    test "create_base_image/1 with conflicting version for the same base image collection fails" do
      collection = create_base_image_collection!()
      base_image_fixture(base_image_collection: collection, version: "1.3.0")

      assert {:error, %Ecto.Changeset{} = changeset} =
               create_base_image(base_image_collection: collection, version: "1.3.0")

      assert "has already been taken" in errors_on(changeset).version
    end

    test "create_base_image/1 with invalid parameters does not upload the image to the storage" do
      expect(StorageMock, :store, 0, &Mocks.BaseImages.Storage.store/2)
      assert {:error, _} = create_base_image(version: "invalid")
    end

    test "update_base_image/2 with valid data updates the base_image" do
      base_image = base_image_fixture()

      attrs = %{
        description: %{"en-US" => "Updated description"},
        release_display_name: %{"en-US" => "Updated display name"},
        starting_version_requirement: "~> 1.2"
      }

      assert {:ok, %BaseImage{} = base_image} = BaseImages.update_base_image(base_image, attrs)

      assert base_image.description == %{"en-US" => "Updated description"}
      assert base_image.release_display_name == %{"en-US" => "Updated display name"}
      assert base_image.starting_version_requirement == "~> 1.2"
    end

    test "update_base_image/1 with invalid description locale returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               update_base_image(description: %{"notAlocale" => "baz"})

      assert "notAlocale is not a valid locale" in errors_on(changeset).description
    end

    test "update_base_image/1 with invalid release display name locale returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               update_base_image(release_display_name: %{"notAlocale" => "baz"})

      assert "notAlocale is not a valid locale" in errors_on(changeset).release_display_name
    end

    test "update_base_image/1 with invalid supported starting version returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               update_base_image(starting_version_requirement: "invalid")

      assert "is not a valid version requirement" in errors_on(changeset).starting_version_requirement
    end

    test "delete_base_image/1 deletes the base_image" do
      base_image = base_image_fixture()
      assert {:ok, %BaseImage{}} = BaseImages.delete_base_image(base_image)
      assert {:error, :not_found} = BaseImages.fetch_base_image(base_image.id)
    end

    test "delete_base_image/1 deletes the base image from the storage" do
      base_image = base_image_fixture()
      expect(StorageMock, :delete, &Mocks.BaseImages.Storage.delete/1)
      assert {:ok, _} = BaseImages.delete_base_image(base_image)
    end

    test "delete_base_image/1 fails if the deletion from the storage fails" do
      base_image = base_image_fixture()
      expect(StorageMock, :delete, fn _ -> {:error, :network_error} end)
      assert {:error, :network_error} = BaseImages.delete_base_image(base_image)
      assert BaseImages.fetch_base_image(base_image.id) == {:ok, base_image}
    end

    test "change_base_image/1 returns a base_image changeset" do
      base_image = base_image_fixture()
      assert %Ecto.Changeset{} = BaseImages.change_base_image(base_image)
    end
  end

  defp create_base_image_collection!(opts \\ []) do
    # TODO: we need this helper until the lazy creation of nested resources is pushed up to their
    # relative fixtures
    hardware_type = Keyword.get_lazy(opts, :hardware_type, fn -> hardware_type_fixture() end)

    system_model =
      Keyword.get_lazy(opts, :system_model, fn -> system_model_fixture(hardware_type) end)

    base_image_collection_fixture(system_model, opts)
  end

  defp create_base_image(opts \\ []) do
    base_image_collection =
      Keyword.get_lazy(opts, :base_image_collection, fn ->
        create_base_image_collection!()
      end)

    attrs =
      Enum.into(opts, %{
        version: unique_base_image_version(),
        file: %Plug.Upload{path: "/tmp/ota.bin", filename: "ota.bin"}
      })

    BaseImages.create_base_image(base_image_collection, attrs)
  end

  defp update_base_image(opts) do
    base_image = Keyword.get_lazy(opts, :base_image, fn -> base_image_fixture() end)

    attrs = Enum.into(opts, %{})

    BaseImages.update_base_image(base_image, attrs)
  end
end
