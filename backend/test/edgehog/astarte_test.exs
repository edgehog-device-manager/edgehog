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

defmodule Edgehog.AstarteTest do
  use Edgehog.DataCase
  use Edgehog.AstarteMockCase

  alias Edgehog.Astarte

  describe "clusters" do
    alias Edgehog.Astarte.Cluster

    import Edgehog.AstarteFixtures

    @invalid_attrs %{base_api_url: nil, name: nil}

    test "list_clusters/0 returns all clusters" do
      cluster = cluster_fixture()
      assert Astarte.list_clusters() == [cluster]
    end

    test "get_cluster!/1 returns the cluster with given id" do
      cluster = cluster_fixture()
      assert Astarte.get_cluster!(cluster.id) == cluster
    end

    test "create_cluster/1 with valid data creates a cluster" do
      valid_attrs = %{base_api_url: "some base_api_url", name: "some name"}

      assert {:ok, %Cluster{} = cluster} = Astarte.create_cluster(valid_attrs)
      assert cluster.base_api_url == "some base_api_url"
      assert cluster.name == "some name"
    end

    test "create_cluster/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Astarte.create_cluster(@invalid_attrs)
    end

    test "update_cluster/2 with valid data updates the cluster" do
      cluster = cluster_fixture()
      update_attrs = %{base_api_url: "some updated base_api_url", name: "some updated name"}

      assert {:ok, %Cluster{} = cluster} = Astarte.update_cluster(cluster, update_attrs)
      assert cluster.base_api_url == "some updated base_api_url"
      assert cluster.name == "some updated name"
    end

    test "update_cluster/2 with invalid data returns error changeset" do
      cluster = cluster_fixture()
      assert {:error, %Ecto.Changeset{}} = Astarte.update_cluster(cluster, @invalid_attrs)
      assert cluster == Astarte.get_cluster!(cluster.id)
    end

    test "delete_cluster/1 deletes the cluster" do
      cluster = cluster_fixture()
      assert {:ok, %Cluster{}} = Astarte.delete_cluster(cluster)
      assert_raise Ecto.NoResultsError, fn -> Astarte.get_cluster!(cluster.id) end
    end

    test "change_cluster/1 returns a cluster changeset" do
      cluster = cluster_fixture()
      assert %Ecto.Changeset{} = Astarte.change_cluster(cluster)
    end
  end

  describe "realms" do
    alias Edgehog.Astarte.Realm

    import Edgehog.AstarteFixtures

    setup do
      %{cluster: cluster_fixture()}
    end

    @invalid_attrs %{name: nil, private_key: nil}

    test "list_realms/0 returns all realms", %{cluster: cluster} do
      realm = realm_fixture(cluster)
      assert Astarte.list_realms() == [realm]
    end

    test "get_realm!/1 returns the realm with given id", %{cluster: cluster} do
      realm = realm_fixture(cluster)
      assert Astarte.get_realm!(realm.id) == realm
    end

    test "create_realm/1 with valid data creates a realm", %{cluster: cluster} do
      valid_attrs = %{name: "somename", private_key: "some private_key"}

      assert {:ok, %Realm{} = realm} = Astarte.create_realm(cluster, valid_attrs)
      assert realm.name == "somename"
      assert realm.private_key == "some private_key"
    end

    test "create_realm/1 with invalid data returns error changeset", %{cluster: cluster} do
      assert {:error, %Ecto.Changeset{}} = Astarte.create_realm(cluster, @invalid_attrs)
    end

    test "update_realm/2 with valid data updates the realm", %{cluster: cluster} do
      realm = realm_fixture(cluster)
      update_attrs = %{name: "someupdatedname", private_key: "some updated private_key"}

      assert {:ok, %Realm{} = realm} = Astarte.update_realm(realm, update_attrs)
      assert realm.name == "someupdatedname"
      assert realm.private_key == "some updated private_key"
    end

    test "update_realm/2 with invalid data returns error changeset", %{cluster: cluster} do
      realm = realm_fixture(cluster)
      assert {:error, %Ecto.Changeset{}} = Astarte.update_realm(realm, @invalid_attrs)
      assert realm == Astarte.get_realm!(realm.id)
    end

    test "delete_realm/1 deletes the realm", %{cluster: cluster} do
      realm = realm_fixture(cluster)
      assert {:ok, %Realm{}} = Astarte.delete_realm(realm)
      assert_raise Ecto.NoResultsError, fn -> Astarte.get_realm!(realm.id) end
    end

    test "change_realm/1 returns a realm changeset", %{cluster: cluster} do
      realm = realm_fixture(cluster)
      assert %Ecto.Changeset{} = Astarte.change_realm(realm)
    end
  end

  describe "devices" do
    alias Edgehog.Astarte.Device

    import Edgehog.AstarteFixtures
    import Edgehog.DevicesFixtures

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

      _system_model = system_model_fixture(hardware_type_fixture(), part_numbers: [part_number])

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
  end
end
