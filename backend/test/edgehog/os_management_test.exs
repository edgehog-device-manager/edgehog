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

    import Edgehog.AstarteFixtures
    import Edgehog.OSManagementFixtures

    setup do
      device =
        cluster_fixture()
        |> realm_fixture()
        |> device_fixture()

      %{device: device}
    end

    @invalid_attrs %{image_url: nil, status: "invalid status"}

    test "list_ota_operations/0 returns all ota_operations", %{device: device} do
      ota_operation = ota_operation_fixture(device)
      assert OSManagement.list_ota_operations() == [ota_operation]
    end

    test "get_ota_operation!/1 returns the ota_operation with given id", %{device: device} do
      ota_operation = ota_operation_fixture(device)
      assert OSManagement.get_ota_operation!(ota_operation.id) == ota_operation
    end

    test "create_ota_operation/1 with valid data creates a ota_operation", %{device: device} do
      valid_attrs = %{
        image_url: "https://updates.acme.com/ota_image_v2"
      }

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.create_ota_operation(device, valid_attrs)

      assert ota_operation.image_url == "https://updates.acme.com/ota_image_v2"
      assert ota_operation.status == :pending
    end

    test "create_ota_operation/1 with invalid data returns error changeset", %{device: device} do
      assert {:error, %Ecto.Changeset{}} =
               OSManagement.create_ota_operation(device, @invalid_attrs)
    end

    test "update_ota_operation/2 with valid data updates the ota_operation", %{device: device} do
      ota_operation = ota_operation_fixture(device)

      update_attrs = %{
        status: :in_progress,
        status_code: "some updated status_code"
      }

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation(ota_operation, update_attrs)

      assert ota_operation.status == :in_progress
      assert ota_operation.status_code == "some updated status_code"
    end

    test "update_ota_operation/2 with invalid data returns error changeset", %{device: device} do
      ota_operation = ota_operation_fixture(device)

      assert {:error, %Ecto.Changeset{}} =
               OSManagement.update_ota_operation(ota_operation, @invalid_attrs)

      assert ota_operation == OSManagement.get_ota_operation!(ota_operation.id)
    end

    test "delete_ota_operation/1 deletes the ota_operation", %{device: device} do
      ota_operation = ota_operation_fixture(device)
      assert {:ok, %OTAOperation{}} = OSManagement.delete_ota_operation(ota_operation)

      assert_raise Ecto.NoResultsError, fn ->
        OSManagement.get_ota_operation!(ota_operation.id)
      end
    end

    test "change_ota_operation/1 returns a ota_operation changeset", %{device: device} do
      ota_operation = ota_operation_fixture(device)
      assert %Ecto.Changeset{} = OSManagement.change_ota_operation(ota_operation)
    end
  end
end
