defmodule Edgehog.AstarteTest do
  use Edgehog.DataCase

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
      valid_attrs = %{name: "some name", private_key: "some private_key"}

      assert {:ok, %Realm{} = realm} = Astarte.create_realm(cluster, valid_attrs)
      assert realm.name == "some name"
      assert realm.private_key == "some private_key"
    end

    test "create_realm/1 with invalid data returns error changeset", %{cluster: cluster} do
      assert {:error, %Ecto.Changeset{}} = Astarte.create_realm(cluster, @invalid_attrs)
    end

    test "update_realm/2 with valid data updates the realm", %{cluster: cluster} do
      realm = realm_fixture(cluster)
      update_attrs = %{name: "some updated name", private_key: "some updated private_key"}

      assert {:ok, %Realm{} = realm} = Astarte.update_realm(realm, update_attrs)
      assert realm.name == "some updated name"
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

    setup do
      cluster = cluster_fixture()

      %{realm: realm_fixture(cluster)}
    end

    @invalid_attrs %{device_id: nil, name: nil}

    test "list_devices/0 returns all devices", %{realm: realm} do
      device = device_fixture(realm)
      assert Astarte.list_devices() == [device]
    end

    test "get_device!/1 returns the device with given id", %{realm: realm} do
      device = device_fixture(realm)
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

    test "update_device/2 with valid data updates the device", %{realm: realm} do
      device = device_fixture(realm)
      update_attrs = %{device_id: "some updated device_id", name: "some updated name"}

      assert {:ok, %Device{} = device} = Astarte.update_device(device, update_attrs)
      assert device.device_id == "some updated device_id"
      assert device.name == "some updated name"
    end

    test "update_device/2 with invalid data returns error changeset", %{realm: realm} do
      device = device_fixture(realm)
      assert {:error, %Ecto.Changeset{}} = Astarte.update_device(device, @invalid_attrs)
      assert device == Astarte.get_device!(device.id)
    end

    test "delete_device/1 deletes the device", %{realm: realm} do
      device = device_fixture(realm)
      assert {:ok, %Device{}} = Astarte.delete_device(device)
      assert_raise Ecto.NoResultsError, fn -> Astarte.get_device!(device.id) end
    end

    test "change_device/1 returns a device changeset", %{realm: realm} do
      device = device_fixture(realm)
      assert %Ecto.Changeset{} = Astarte.change_device(device)
    end
  end
end
