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

defmodule Edgehog.OSManagementTest do
  use Edgehog.DataCase

  alias Edgehog.OSManagement

  describe "ota_operations" do
    alias Edgehog.OSManagement.OTAOperation

    import Edgehog.OSManagementFixtures

    @invalid_attrs %{image_url: nil, status: nil, status_code: nil}

    test "list_ota_operations/0 returns all ota_operations" do
      ota_operation = ota_operation_fixture()
      assert OSManagement.list_ota_operations() == [ota_operation]
    end

    test "get_ota_operation!/1 returns the ota_operation with given id" do
      ota_operation = ota_operation_fixture()
      assert OSManagement.get_ota_operation!(ota_operation.id) == ota_operation
    end

    test "create_ota_operation/1 with valid data creates a ota_operation" do
      valid_attrs = %{
        image_url: "some image_url",
        status: "some status",
        status_code: "some status_code"
      }

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.create_ota_operation(valid_attrs)

      assert ota_operation.image_url == "some image_url"
      assert ota_operation.status == "some status"
      assert ota_operation.status_code == "some status_code"
    end

    test "create_ota_operation/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = OSManagement.create_ota_operation(@invalid_attrs)
    end

    test "update_ota_operation/2 with valid data updates the ota_operation" do
      ota_operation = ota_operation_fixture()

      update_attrs = %{
        image_url: "some updated image_url",
        status: "some updated status",
        status_code: "some updated status_code"
      }

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation(ota_operation, update_attrs)

      assert ota_operation.image_url == "some updated image_url"
      assert ota_operation.status == "some updated status"
      assert ota_operation.status_code == "some updated status_code"
    end

    test "update_ota_operation/2 with invalid data returns error changeset" do
      ota_operation = ota_operation_fixture()

      assert {:error, %Ecto.Changeset{}} =
               OSManagement.update_ota_operation(ota_operation, @invalid_attrs)

      assert ota_operation == OSManagement.get_ota_operation!(ota_operation.id)
    end

    test "delete_ota_operation/1 deletes the ota_operation" do
      ota_operation = ota_operation_fixture()
      assert {:ok, %OTAOperation{}} = OSManagement.delete_ota_operation(ota_operation)

      assert_raise Ecto.NoResultsError, fn ->
        OSManagement.get_ota_operation!(ota_operation.id)
      end
    end

    test "change_ota_operation/1 returns a ota_operation changeset" do
      ota_operation = ota_operation_fixture()
      assert %Ecto.Changeset{} = OSManagement.change_ota_operation(ota_operation)
    end
  end
end
