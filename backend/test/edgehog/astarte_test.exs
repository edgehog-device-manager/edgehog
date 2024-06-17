#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule Edgehog.AstarteTest do
  use Edgehog.DataCase, async: true
  use Edgehog.AstarteMockCase

  alias Astarte.Client.APIError
  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device.DeviceStatus
  alias Edgehog.Astarte.InterfaceVersion

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  describe "send_ota_request_update/4" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      %{base_api_url: base_api_url} = cluster
      %{name: realm_name, private_key: private_key} = realm

      {:ok, client} = AppEngine.new(base_api_url, realm_name, private_key: private_key)

      {:ok, device: device_fixture(realm), client: client}
    end

    test "sends the request for io.edgehog.devicemanager.OTARequest v1.0", ctx do
      %{device: device, client: client} = ctx

      introspection = %{
        "io.edgehog.devicemanager.OTARequest" => %{major: 1, minor: 0}
      }

      mock_device_status_introspection(device, introspection)

      device_id = device.device_id
      uuid = Ecto.UUID.generate()
      url = "https://mybucket.foo/update.bin"

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn ^client, ^device_id, ^uuid, ^url ->
        :ok
      end)

      assert :ok = Astarte.send_ota_request_update(client, device_id, uuid, url)
    end

    test "sends the request for io.edgehog.devicemanager.OTARequest v0.1", ctx do
      %{device: device, client: client} = ctx

      introspection = %{
        "io.edgehog.devicemanager.OTARequest" => %{major: 0, minor: 1}
      }

      mock_device_status_introspection(device, introspection)

      device_id = device.device_id
      uuid = Ecto.UUID.generate()
      url = "https://mybucket.foo/update.bin"

      Edgehog.Astarte.Device.OTARequestV0Mock
      |> expect(:post, fn ^client, ^device_id, ^uuid, ^url ->
        :ok
      end)

      assert :ok = Astarte.send_ota_request_update(client, device_id, uuid, url)
    end

    test "fails if the API returns a failure", ctx do
      %{device: device, client: client} = ctx

      introspection = %{
        "io.edgehog.devicemanager.OTARequest" => %{major: 1, minor: 0}
      }

      mock_device_status_introspection(device, introspection)

      device_id = device.device_id
      uuid = Ecto.UUID.generate()
      url = "https://mybucket.foo/update.bin"

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, fn ^client, ^device_id, ^uuid, ^url ->
        {:error,
         %APIError{
           status: 500,
           response: %{"errors" => %{"detail" => "Internal server error"}}
         }}
      end)

      assert {:error, %APIError{status: 500}} =
               Astarte.send_ota_request_update(client, device_id, uuid, url)
    end

    test "fails if the device doesn't have the OTARequest interface", ctx do
      %{device: device, client: client} = ctx

      introspection = []
      mock_device_status_introspection(device, introspection)

      device_id = device.device_id
      uuid = Ecto.UUID.generate()
      url = "https://mybucket.foo/update.bin"

      Edgehog.Astarte.Device.OTARequestV0Mock
      |> expect(:post, 0, fn _client, _device_id, _uuid, _url -> :ok end)

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:update, 0, fn _client, _device_id, _uuid, _url -> :ok end)

      assert {:error, :ota_request_not_supported} =
               Astarte.send_ota_request_update(client, device_id, uuid, url)
    end
  end

  describe "send_ota_request_cancel/3" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      %{base_api_url: base_api_url} = cluster
      %{name: realm_name, private_key: private_key} = realm

      {:ok, client} = AppEngine.new(base_api_url, realm_name, private_key: private_key)

      {:ok, device: device_fixture(realm), client: client}
    end

    test "sends the request for io.edgehog.devicemanager.OTARequest v1.0", ctx do
      %{device: device, client: client} = ctx

      introspection = %{
        "io.edgehog.devicemanager.OTARequest" => %{major: 1, minor: 0}
      }

      mock_device_status_introspection(device, introspection)

      device_id = device.device_id
      uuid = Ecto.UUID.generate()

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:cancel, fn ^client, ^device_id, ^uuid ->
        :ok
      end)

      assert :ok = Astarte.send_ota_request_cancel(client, device_id, uuid)
    end

    test "fails for io.edgehog.devicemanager.OTARequest v0.1", ctx do
      %{device: device, client: client} = ctx

      introspection = %{
        "io.edgehog.devicemanager.OTARequest" => %{major: 0, minor: 1}
      }

      mock_device_status_introspection(device, introspection)

      device_id = device.device_id
      uuid = Ecto.UUID.generate()

      assert {:error, :cancel_not_supported} =
               Astarte.send_ota_request_cancel(client, device_id, uuid)
    end

    test "fails if the API returns a failure", ctx do
      %{device: device, client: client} = ctx

      introspection = %{
        "io.edgehog.devicemanager.OTARequest" => %{major: 1, minor: 0}
      }

      mock_device_status_introspection(device, introspection)

      device_id = device.device_id
      uuid = Ecto.UUID.generate()

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:cancel, fn ^client, ^device_id, ^uuid ->
        {:error,
         %APIError{
           status: 500,
           response: %{"errors" => %{"detail" => "Internal server error"}}
         }}
      end)

      assert {:error, %APIError{status: 500}} =
               Astarte.send_ota_request_cancel(client, device_id, uuid)
    end

    test "fails if the device doesn't have the OTARequest interface", ctx do
      %{device: device, client: client} = ctx

      introspection = []
      mock_device_status_introspection(device, introspection)

      device_id = device.device_id
      uuid = Ecto.UUID.generate()

      Edgehog.Astarte.Device.OTARequestV1Mock
      |> expect(:cancel, 0, fn _client, _device_id, _uuid -> :ok end)

      assert {:error, :ota_request_not_supported} =
               Astarte.send_ota_request_cancel(client, device_id, uuid)
    end
  end

  defp mock_device_status_introspection(device, interfaces) do
    device_id = device.device_id

    introspection =
      for {name, %{major: major, minor: minor}} <- interfaces, into: %{} do
        {name, %InterfaceVersion{major: major, minor: minor}}
      end

    Edgehog.Astarte.Device.DeviceStatusMock
    |> expect(:get, fn _appengine_client, ^device_id ->
      {:ok, %DeviceStatus{introspection: introspection}}
    end)
  end
end
