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

    @invalid_attrs %{handle: nil, name: nil}

    test "list_base_image_collections/0 returns all base_image_collections" do
      base_image_collection = base_image_collection_fixture()
      assert BaseImages.list_base_image_collections() == [base_image_collection]
    end

    test "get_base_image_collection!/1 returns the base_image_collection with given id" do
      base_image_collection = base_image_collection_fixture()

      assert BaseImages.get_base_image_collection!(base_image_collection.id) ==
               base_image_collection
    end

    test "create_base_image_collection/1 with valid data creates a base_image_collection" do
      valid_attrs = %{handle: "some handle", name: "some name"}

      assert {:ok, %BaseImageCollection{} = base_image_collection} =
               BaseImages.create_base_image_collection(valid_attrs)

      assert base_image_collection.handle == "some handle"
      assert base_image_collection.name == "some name"
    end

    test "create_base_image_collection/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = BaseImages.create_base_image_collection(@invalid_attrs)
    end

    test "update_base_image_collection/2 with valid data updates the base_image_collection" do
      base_image_collection = base_image_collection_fixture()
      update_attrs = %{handle: "some updated handle", name: "some updated name"}

      assert {:ok, %BaseImageCollection{} = base_image_collection} =
               BaseImages.update_base_image_collection(base_image_collection, update_attrs)

      assert base_image_collection.handle == "some updated handle"
      assert base_image_collection.name == "some updated name"
    end

    test "update_base_image_collection/2 with invalid data returns error changeset" do
      base_image_collection = base_image_collection_fixture()

      assert {:error, %Ecto.Changeset{}} =
               BaseImages.update_base_image_collection(base_image_collection, @invalid_attrs)

      assert base_image_collection ==
               BaseImages.get_base_image_collection!(base_image_collection.id)
    end

    test "delete_base_image_collection/1 deletes the base_image_collection" do
      base_image_collection = base_image_collection_fixture()

      assert {:ok, %BaseImageCollection{}} =
               BaseImages.delete_base_image_collection(base_image_collection)

      assert_raise Ecto.NoResultsError, fn ->
        BaseImages.get_base_image_collection!(base_image_collection.id)
      end
    end

    test "change_base_image_collection/1 returns a base_image_collection changeset" do
      base_image_collection = base_image_collection_fixture()
      assert %Ecto.Changeset{} = BaseImages.change_base_image_collection(base_image_collection)
    end
  end
end
