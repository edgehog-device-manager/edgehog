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

defmodule Edgehog.OSManagementTest do
  use Edgehog.AstarteMockCase
  use Edgehog.DataCase
  use Edgehog.EphemeralImageMockCase

  alias Edgehog.Devices
  alias Edgehog.OSManagement

  describe "ota_operations" do
    alias Edgehog.OSManagement.OTAOperation

    import Edgehog.AstarteFixtures
    import Edgehog.BaseImagesFixtures
    import Edgehog.DevicesFixtures
    import Edgehog.OSManagementFixtures

    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      device =
        device_fixture(realm)
        |> Devices.preload_astarte_resources_for_device()

      %{cluster: cluster, realm: realm, device: device}
    end

    @invalid_attrs %{base_image_url: nil, status: "invalid status"}

    test "list_ota_operations/0 returns all ota_operations", %{device: device} do
      ota_operation = manual_ota_operation_fixture(device)
      assert OSManagement.list_ota_operations() == [ota_operation]
    end

    test "list_device_ota_operations/1 just returns the device ota_operations", %{
      device: device,
      realm: realm
    } do
      ota_operation = manual_ota_operation_fixture(device)
      other_device = device_fixture(realm)

      other_ota_operation = manual_ota_operation_fixture(other_device)
      assert OSManagement.list_ota_operations() == [ota_operation, other_ota_operation]
      assert OSManagement.list_device_ota_operations(device) == [ota_operation]
    end

    test "get_ota_operation!/1 returns the ota_operation with given id", %{device: device} do
      ota_operation = manual_ota_operation_fixture(device)
      assert OSManagement.get_ota_operation!(ota_operation.id) == ota_operation
    end

    test "create_manual_ota_operation/2 with valid data creates an ota_operation", %{
      device: device
    } do
      bucket_url = "https://updates.acme.com"
      fake_image = %Plug.Upload{path: "/tmp/ota_image_v2.bin", filename: "ota_image_v2.bin"}

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:upload, fn tenant_id, ota_operation_id, upload ->
        assert fake_image == upload

        file_name =
          "uploads/tenants/#{tenant_id}/ephemeral_ota_images/#{ota_operation_id}/#{upload.filename}"

        file_url = "#{bucket_url}/#{file_name}"
        {:ok, file_url}
      end)

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _client, device_id, _uuid, _url ->
        assert device_id == device.device_id
        :ok
      end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.create_manual_ota_operation(device, fake_image)

      assert ota_operation.base_image_url =~ bucket_url
      assert ota_operation.base_image_url =~ ota_operation.id
      assert ota_operation.base_image_url =~ fake_image.filename
      assert ota_operation.status == :pending
      assert ota_operation.status_code == nil
      assert ota_operation.manual? == true
    end

    test "create_manual_ota_operation/2 fails if upload fails", %{device: device} do
      fake_image = %Plug.Upload{path: "/tmp/ota_image_v2.bin", filename: "ota_image_v2.bin"}

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:upload, fn _tenant_id, _ota_operation_id, _upload ->
        {:error, :cannot_upload}
      end)

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, 0, fn _client, _device_id, _uuid, _url ->
        :ok
      end)

      assert {:error, :cannot_upload} =
               OSManagement.create_manual_ota_operation(device, fake_image)
    end

    test "create_manual_ota_operation/2 fails and deletes the upload if the Astarte request fails",
         %{
           device: device
         } do
      bucket_url = "https://updates.acme.com"
      fake_image = %Plug.Upload{path: "/tmp/ota_image_v2.bin", filename: "ota_image_v2.bin"}

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:upload, fn tenant_id, ota_operation_id, upload ->
        assert fake_image == upload

        file_name =
          "uploads/tenants/#{tenant_id}/ephemeral_ota_images/#{ota_operation_id}/#{upload.filename}"

        file_url = "#{bucket_url}/#{file_name}"
        {:ok, file_url}
      end)
      |> expect(:delete, fn _tenant_id, _ota_operation_id, url ->
        assert url =~ bucket_url
        assert url =~ fake_image.filename

        :ok
      end)

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _client, _device_id, _uuid, _url ->
        {:error, %Astarte.Client.APIError{status: 503, response: "Cannot push to device"}}
      end)

      assert {:error, %Astarte.Client.APIError{}} =
               OSManagement.create_manual_ota_operation(device, fake_image)
    end

    test "create_managed_ota_operation/2 with valid data creates an ota_operation", %{
      device: device
    } do
      base_image = base_image_fixture()

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _client, device_id, _uuid, url ->
        assert device_id == device.device_id
        assert url == base_image.url
        :ok
      end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.create_managed_ota_operation(device, base_image)

      assert ota_operation.base_image_url == base_image.url
      assert ota_operation.status == :pending
      assert ota_operation.status_code == nil
      assert ota_operation.manual? == false
    end

    test "create_managed_ota_operation/2 fails if the Astarte request fails", %{
      device: device
    } do
      base_image = base_image_fixture()

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn _client, _device_id, _uuid, _url ->
        {:error, %Astarte.Client.APIError{status: 503, response: "Cannot push to device"}}
      end)

      assert {:error, %Astarte.Client.APIError{}} =
               OSManagement.create_managed_ota_operation(device, base_image)
    end

    test "update_ota_operation/2 with valid data updates the ota_operation", %{device: device} do
      ota_operation = manual_ota_operation_fixture(device)

      update_attrs = %{
        status: :acknowledged
      }

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation(ota_operation, update_attrs)

      assert ota_operation.status == :acknowledged
    end

    test "update_ota_operation/2 with success status deletes the image for a manual ota_operation",
         %{device: device} do
      ota_operation = manual_ota_operation_fixture(device)

      update_attrs = %{status: :success, status_code: ""}

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:delete, fn tenant_id, ota_operation_id, url ->
        assert tenant_id == ota_operation.tenant_id
        assert ota_operation_id == ota_operation.id
        assert url == ota_operation.base_image_url

        :ok
      end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation(ota_operation, update_attrs)

      assert ota_operation.status == :success
      assert ota_operation.status_code == nil
    end

    test "update_ota_operation/2 with failure status deletes the image for a manual ota_operation",
         %{device: device} do
      ota_operation = manual_ota_operation_fixture(device)

      update_attrs = %{status: :failure, status_code: "NetworkError"}

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:delete, fn tenant_id, ota_operation_id, url ->
        assert tenant_id == ota_operation.tenant_id
        assert ota_operation_id == ota_operation.id
        assert url == ota_operation.base_image_url

        :ok
      end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation(ota_operation, update_attrs)

      assert ota_operation.status == :failure
      assert ota_operation.status_code == :network_error
    end

    test "update_ota_operation/2 with success status doesn't delete the image for a managed ota_operation",
         %{device: device} do
      ota_operation = managed_ota_operation_fixture(device)

      update_attrs = %{status: :success, status_code: ""}

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:delete, 0, fn _tenant_id, _ota_operation_id, _url -> :ok end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation(ota_operation, update_attrs)

      assert ota_operation.status == :success
      assert ota_operation.status_code == nil
    end

    test "update_ota_operation/2 with failure status doesn't delete the image for a managed ota_operation",
         %{device: device} do
      ota_operation = managed_ota_operation_fixture(device)

      update_attrs = %{status: :failure, status_code: "NetworkError"}

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:delete, 0, fn _tenant_id, _ota_operation_id, _url -> :ok end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation(ota_operation, update_attrs)

      assert ota_operation.status == :failure
      assert ota_operation.status_code == :network_error
    end

    test "update_ota_operation/2 with invalid data returns error changeset", %{device: device} do
      ota_operation = manual_ota_operation_fixture(device)

      assert {:error, %Ecto.Changeset{}} =
               OSManagement.update_ota_operation(ota_operation, @invalid_attrs)

      assert ota_operation == OSManagement.get_ota_operation!(ota_operation.id)
    end

    test "delete_ota_operation/1 deletes the ota_operation", %{device: device} do
      ota_operation = manual_ota_operation_fixture(device)
      assert {:ok, %OTAOperation{}} = OSManagement.delete_ota_operation(ota_operation)

      assert_raise Ecto.NoResultsError, fn ->
        OSManagement.get_ota_operation!(ota_operation.id)
      end
    end

    test "delete_ota_operation/1 removes the ephemeral image for a manual ota_operation", %{
      device: device
    } do
      ota_operation = manual_ota_operation_fixture(device)

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:delete, fn tenant_id, ota_operation_id, url ->
        assert tenant_id == ota_operation.tenant_id
        assert ota_operation_id == ota_operation.id
        assert url == ota_operation.base_image_url

        :ok
      end)

      assert {:ok, %OTAOperation{}} = OSManagement.delete_ota_operation(ota_operation)
    end

    test "delete_ota_operation/1 doesn't remove the image for a managed ota_operation", %{
      device: device
    } do
      ota_operation = managed_ota_operation_fixture(device)

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:delete, 0, fn _tenant_id, _ota_operation_id, _url -> :ok end)

      assert {:ok, %OTAOperation{}} = OSManagement.delete_ota_operation(ota_operation)
    end

    test "change_ota_operation/1 returns a ota_operation changeset", %{device: device} do
      ota_operation = manual_ota_operation_fixture(device)
      assert %Ecto.Changeset{} = OSManagement.change_ota_operation(ota_operation)
    end
  end
end
