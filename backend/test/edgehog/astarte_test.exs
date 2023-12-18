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
  alias Astarte.Client.RealmManagement
  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device.DeviceStatus
  alias Edgehog.Astarte.InterfaceVersion

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  describe "devices" do
    alias Edgehog.Astarte.Device

    setup do
      cluster = cluster_fixture()

      %{realm: realm_fixture(cluster)}
    end

    @invalid_attrs %{device_id: nil, name: nil}

    test "get_device!/1 returns the device with given id", %{realm: realm} do
      device = astarte_device_fixture(realm)
      assert Astarte.get_device!(device.id) == device
    end

    test "create_device/1 with valid data creates a device", %{realm: realm} do
      valid_attrs = %{device_id: "some device_id", name: "some name"}

      assert {:ok, %Device{} = device} = Astarte.create_device(realm, valid_attrs)
      assert device.device_id == "some device_id"
      assert device.name == "some name"
    end

    test "create_device/1 with invalid data returns error changeset", %{realm: realm} do
      assert {:error, %Ecto.Changeset{}} = Astarte.create_device(realm, @invalid_attrs)
    end

    test "change_device/1 returns a device changeset", %{realm: realm} do
      device = astarte_device_fixture(realm)
      assert %Ecto.Changeset{} = Astarte.change_device(device)
    end

    test "ensure_device_exists/1 creates a device if not existent", %{realm: realm} do
      device_id = "does_not_exist"
      {:ok, device} = Astarte.ensure_device_exists(realm, device_id)
      assert %Device{device_id: ^device_id} = device
    end

    test "ensure_device_exists/1 does not create a device if already existent", %{realm: realm} do
      device = astarte_device_fixture(realm)
      {:ok, same_device} = Astarte.ensure_device_exists(realm, device.device_id)
      assert same_device.id == device.id
    end

    test "process_device_event/4 ignores unknown event", %{realm: realm} do
      device = astarte_device_fixture(realm)
      device_id = device.device_id
      event = %{"type" => "unknown"}
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
      assert :ok = Astarte.process_device_event(realm, device_id, event, timestamp)

      assert ^device = Astarte.get_device!(device.id)
    end

    test "process_device_event/4 updates online and last_connection on device_connected event", %{
      realm: realm
    } do
      device = astarte_device_fixture(realm, %{online: false, last_connection: nil})
      assert device.online == false
      assert device.last_connection == nil

      device_id = device.device_id
      event = %{"type" => "device_connected"}
      timestamp = DateTime.utc_now()
      timestamp_string = DateTime.to_iso8601(timestamp)
      assert :ok = Astarte.process_device_event(realm, device_id, event, timestamp_string)

      assert device = Astarte.get_device!(device.id)
      assert device.online == true
      assert device.last_connection == timestamp |> DateTime.truncate(:second)
    end

    test "process_device_event/4 updates online and last_disconnection on device_disconnected event",
         %{realm: realm} do
      device = astarte_device_fixture(realm, %{online: true, last_disconnection: nil})

      assert device.online == true
      assert device.last_disconnection == nil

      device_id = device.device_id
      event = %{"type" => "device_disconnected"}
      timestamp = DateTime.utc_now()
      timestamp_string = DateTime.to_iso8601(timestamp)
      assert :ok = Astarte.process_device_event(realm, device_id, event, timestamp_string)

      assert device = Astarte.get_device!(device.id)
      assert device.online == false
      assert device.last_disconnection == timestamp |> DateTime.truncate(:second)
    end

    @system_info_interface "io.edgehog.devicemanager.SystemInfo"

    test "process_device_event/4 updates serial number on incoming_data event",
         %{realm: realm} do
      device = astarte_device_fixture(realm)

      assert device.serial_number == nil

      device_id = device.device_id

      event = %{
        "type" => "incoming_data",
        "interface" => @system_info_interface,
        "path" => "/serialNumber",
        "value" => "42"
      }

      timestamp = DateTime.utc_now()
      timestamp_string = DateTime.to_iso8601(timestamp)
      assert :ok = Astarte.process_device_event(realm, device_id, event, timestamp_string)

      assert device = Astarte.get_device!(device.id)
      assert device.serial_number == "42"
    end

    test "process_device_event/4 updates part number on incoming_data event",
         %{realm: realm} do
      device = astarte_device_fixture(realm)
      assert device.part_number == nil

      part_number = "XYZ123"

      _system_model = system_model_fixture(part_numbers: [part_number])

      device_id = device.device_id

      event = %{
        "type" => "incoming_data",
        "interface" => @system_info_interface,
        "path" => "/partNumber",
        "value" => part_number
      }

      timestamp = DateTime.utc_now()
      timestamp_string = DateTime.to_iso8601(timestamp)
      assert :ok = Astarte.process_device_event(realm, device_id, event, timestamp_string)

      device = Astarte.get_device!(device.id)

      assert device.part_number == part_number
    end

    test "process_device_event/4 updates part number on incoming_data event when SystemModelPartNumber does not exist",
         %{realm: realm} do
      device = astarte_device_fixture(realm)
      assert device.part_number == nil

      device_id = device.device_id

      part_number = "PN1234567890"

      event = %{
        "type" => "incoming_data",
        "interface" => @system_info_interface,
        "path" => "/partNumber",
        "value" => part_number
      }

      timestamp_string =
        DateTime.utc_now()
        |> DateTime.to_iso8601()

      assert :ok = Astarte.process_device_event(realm, device_id, event, timestamp_string)

      device = Astarte.get_device!(device.id)

      assert device.part_number == part_number
    end
  end

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
