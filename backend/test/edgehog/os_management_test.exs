#
# This file is part of Edgehog.
#
# Copyright 2022-2025 SECO Mind Srl
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
  use Edgehog.DataCase, async: true

  alias Ash.Error.Invalid
  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.OTARequestV1Mock
  alias Edgehog.Error.AstarteAPIError
  alias Edgehog.OSManagement
  alias Edgehog.OSManagement.EphemeralImageMock

  describe "ota_operations" do
    import Edgehog.BaseImagesFixtures
    import Edgehog.DevicesFixtures
    import Edgehog.OSManagementFixtures
    import Edgehog.TenantsFixtures

    alias Edgehog.OSManagement.OTAOperation

    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)

      %{tenant: tenant, device: device}
    end

    test "create_managed_ota_operation/2 with valid data creates an ota_operation", %{
      device: device,
      tenant: tenant
    } do
      base_image = base_image_fixture(tenant: tenant)

      expect(OTARequestV1Mock, :update, fn _client, device_id, _uuid, url ->
        assert device_id == device.device_id
        assert url == base_image.url
        :ok
      end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.create_managed_ota_operation(
                 %{device_id: device.id, base_image_url: base_image.url},
                 tenant: tenant
               )

      assert ota_operation.base_image_url == base_image.url
      assert ota_operation.status == :pending
      assert ota_operation.status_code == nil
      assert ota_operation.manual? == false
    end

    test "successful create_managed_ota_operation/2 publishes on PubSub", %{
      tenant: tenant,
      device: device
    } do
      base_image = base_image_fixture(tenant: tenant)

      assert :ok = Phoenix.PubSub.subscribe(Edgehog.PubSub, "ota_operations:*")

      expect(OTARequestV1Mock, :update, fn _client, _device_id, _uuid, _url -> :ok end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.create_managed_ota_operation(
                 %{device_id: device.id, base_image_url: base_image.url},
                 tenant: tenant
               )

      assert_receive %Phoenix.Socket.Broadcast{
        event: "create_managed",
        payload: %Ash.Notifier.Notification{
          data: ^ota_operation
        }
      }
    end

    test "create_managed_ota_operation/2 fails if the Astarte request fails", %{
      tenant: tenant,
      device: device
    } do
      base_image = base_image_fixture(tenant: tenant)

      expect(OTARequestV1Mock, :update, fn _client, _device_id, _uuid, _url ->
        {:error, %APIError{status: 503, response: "Cannot push to device"}}
      end)

      assert {:error, %Invalid{errors: errors}} =
               OSManagement.create_managed_ota_operation(
                 %{device_id: device.id, base_image_url: base_image.url},
                 tenant: tenant
               )

      assert [%AstarteAPIError{status: 503, response: "Cannot push to device"}] =
               errors
    end

    test "send_update_request/2 succeeds if the Astarte request succeeds", %{
      tenant: tenant,
      device: device
    } do
      base_image_url = "https://my.bucket.example/ota.bin"

      ota_operation =
        manual_ota_operation_fixture(
          device_id: device.id,
          base_image_url: base_image_url,
          tenant: tenant
        )

      device_id = device.device_id
      ota_operation_id = ota_operation.id

      expect(OTARequestV1Mock, :update, fn _client, ^device_id, ^ota_operation_id, ^base_image_url ->
        :ok
      end)

      assert :ok = OSManagement.send_update_request(ota_operation)
    end

    test "send_update_request/2 fails if the Astarte request fails", %{
      tenant: tenant
    } do
      ota_operation = manual_ota_operation_fixture(tenant: tenant)

      expect(OTARequestV1Mock, :update, fn _client, _device_id, _uuid, _fake_url ->
        {:error, %APIError{status: 503, response: "Cannot push to device"}}
      end)

      assert {:error, %Invalid{errors: errors}} =
               OSManagement.send_update_request(ota_operation)

      assert [%AstarteAPIError{status: 503, response: "Cannot push to device"}] =
               errors
    end

    test "update_ota_operation_status/3 with valid data updates the ota_operation", %{
      tenant: tenant
    } do
      ota_operation = manual_ota_operation_fixture(status: :pending, tenant: tenant)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation_status(ota_operation, :acknowledged)

      assert ota_operation.status == :acknowledged
    end

    test "update_ota_operation_status/3 with success status deletes the image for a manual ota_operation",
         %{tenant: tenant} do
      ota_operation = manual_ota_operation_fixture(tenant: tenant)

      expect(EphemeralImageMock, :delete, fn tenant_id, ota_operation_id, url ->
        assert tenant_id == ota_operation.tenant_id
        assert ota_operation_id == ota_operation.id
        assert url == ota_operation.base_image_url

        :ok
      end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation_status(ota_operation, :success, %{
                 status_code: ""
               })

      assert ota_operation.status == :success
      assert ota_operation.status_code == nil
    end

    test "update_ota_operation_status/3 with failure status deletes the image for a manual ota_operation",
         %{tenant: tenant} do
      ota_operation = manual_ota_operation_fixture(tenant: tenant)

      expect(EphemeralImageMock, :delete, fn tenant_id, ota_operation_id, url ->
        assert tenant_id == ota_operation.tenant_id
        assert ota_operation_id == ota_operation.id
        assert url == ota_operation.base_image_url

        :ok
      end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation_status(ota_operation, :failure, %{
                 status_code: "NetworkError"
               })

      assert ota_operation.status == :failure
      assert ota_operation.status_code == :network_error
    end

    test "update_ota_operation_status/3 with a non terminal status does not delete the image of a manual ota_operation",
         %{tenant: tenant} do
      ota_operation = manual_ota_operation_fixture(tenant: tenant)

      expect(EphemeralImageMock, :delete, 0, fn _tenant_id, _ota_operation_id, _url ->
        :unreachable
      end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation_status(ota_operation, :acknowledged)

      assert ota_operation.status == :acknowledged
    end

    test "update_ota_operation_status/3 with success status doesn't delete the image for a managed ota_operation",
         %{tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(tenant: tenant)

      expect(EphemeralImageMock, :delete, 0, fn _tenant_id, _ota_operation_id, _url -> :ok end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation_status(ota_operation, :success)

      assert ota_operation.status == :success
    end

    test "update_ota_operation_status/3 with failure status doesn't delete the image for a managed ota_operation",
         %{tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(tenant: tenant)

      expect(EphemeralImageMock, :delete, 0, fn _tenant_id, _ota_operation_id, _url -> :ok end)

      assert {:ok, %OTAOperation{} = ota_operation} =
               OSManagement.update_ota_operation_status(ota_operation, :failure)

      assert ota_operation.status == :failure
    end

    test "update_ota_operation_status/3 with success status logs the outcome",
         %{tenant: tenant} do
      import ExUnit.CaptureLog

      log_level = Logger.level()
      Logger.configure(level: :info)

      ota_operation = manual_ota_operation_fixture(tenant: tenant)
      expect(EphemeralImageMock, :delete, 1, fn _tenant_id, _ota_operation_id, _url -> :ok end)

      status = "SUCCESS"
      status_attrs = %{status_code: "", message: "Yey!"}

      {result, log} =
        with_log(fn ->
          OSManagement.update_ota_operation_status(ota_operation, status, status_attrs)
        end)

      assert {:ok, %OTAOperation{} = ota_operation} = result

      assert log =~
               "OTA operation #{ota_operation.id} on device #{ota_operation.device_id} completed successfully with status code #{ota_operation.status_code} and message: #{ota_operation.message}"

      Logger.configure(level: log_level)
    end

    test "update_ota_operation_status/3 with failure status logs the outcome",
         %{tenant: tenant} do
      import ExUnit.CaptureLog

      log_level = Logger.level()
      Logger.configure(level: :info)

      ota_operation = manual_ota_operation_fixture(tenant: tenant)
      expect(EphemeralImageMock, :delete, 1, fn _tenant_id, _ota_operation_id, _url -> :ok end)

      status = "FAILURE"
      status_attrs = %{status_code: "SYSTEM_ROLLBACK", message: "Something bad happened"}

      {result, log} =
        with_log(fn ->
          OSManagement.update_ota_operation_status(ota_operation, status, status_attrs)
        end)

      assert {:ok, %OTAOperation{} = ota_operation} = result

      assert log =~
               "OTA operation #{ota_operation.id} on device #{ota_operation.device_id} failed with status code #{ota_operation.status_code} and message: #{ota_operation.message}"

      Logger.configure(level: log_level)
    end

    test "mark_ota_operation_as_timed_out!/2 logs the outcome",
         %{tenant: tenant} do
      import ExUnit.CaptureLog

      log_level = Logger.level()
      Logger.configure(level: :info)

      ota_operation = managed_ota_operation_fixture(tenant: tenant)

      {ota_operation, log} =
        with_log(fn -> OSManagement.mark_ota_operation_as_timed_out!(ota_operation) end)

      assert log =~
               "OTA operation #{ota_operation.id} on device #{ota_operation.device_id} failed with status code request_timeout and message: "

      Logger.configure(level: log_level)
    end
  end
end
