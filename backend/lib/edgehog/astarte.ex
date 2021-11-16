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

defmodule Edgehog.Astarte do
  @moduledoc """
  The Astarte context.
  """

  import Ecto.Query, warn: false
  alias Edgehog.Repo

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Cluster
  alias Edgehog.Astarte.Device.{DeviceStatus, HardwareInfo}

  @appliance_info_interface "io.edgehog.devicemanager.ApplianceInfo"

  @device_status_module Application.compile_env(
                          :edgehog,
                          :astarte_device_status_module,
                          DeviceStatus
                        )

  @doc """
  Returns the list of clusters.

  ## Examples

      iex> list_clusters()
      [%Cluster{}, ...]

  """
  def list_clusters do
    Repo.all(Cluster, skip_tenant_id: true)
  end

  @doc """
  Gets a single cluster.

  Raises `Ecto.NoResultsError` if the Cluster does not exist.

  ## Examples

      iex> get_cluster!(123)
      %Cluster{}

      iex> get_cluster!(456)
      ** (Ecto.NoResultsError)

  """
  def get_cluster!(id), do: Repo.get!(Cluster, id, skip_tenant_id: true)

  @doc """
  Creates a cluster.

  ## Examples

      iex> create_cluster(%{field: value})
      {:ok, %Cluster{}}

      iex> create_cluster(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_cluster(attrs \\ %{}) do
    %Cluster{}
    |> Cluster.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a cluster.

  ## Examples

      iex> update_cluster(cluster, %{field: new_value})
      {:ok, %Cluster{}}

      iex> update_cluster(cluster, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_cluster(%Cluster{} = cluster, attrs) do
    cluster
    |> Cluster.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a cluster.

  ## Examples

      iex> delete_cluster(cluster)
      {:ok, %Cluster{}}

      iex> delete_cluster(cluster)
      {:error, %Ecto.Changeset{}}

  """
  def delete_cluster(%Cluster{} = cluster) do
    Repo.delete(cluster)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking cluster changes.

  ## Examples

      iex> change_cluster(cluster)
      %Ecto.Changeset{data: %Cluster{}}

  """
  def change_cluster(%Cluster{} = cluster, attrs \\ %{}) do
    Cluster.changeset(cluster, attrs)
  end

  alias Edgehog.Astarte.Realm

  @doc """
  Returns the list of realms.

  ## Examples

      iex> list_realms()
      [%Realm{}, ...]

  """
  def list_realms do
    Repo.all(Realm)
  end

  @doc """
  Gets a single realm.

  Raises `Ecto.NoResultsError` if the Realm does not exist.

  ## Examples

      iex> get_realm!(123)
      %Realm{}

      iex> get_realm!(456)
      ** (Ecto.NoResultsError)

  """
  def get_realm!(id), do: Repo.get!(Realm, id)

  @doc """
  Gets a single realm by name, from the current tenant

  ## Examples

      iex> fetch_realm_by_name("existingname")
      {:ok, %Realm{}}

      iex> fetch_realm_by_name("invalidname")
      {:error, :realm_not_found}

  """
  def fetch_realm_by_name(realm_name) do
    case Repo.get_by(Realm, name: realm_name) do
      %Realm{} = realm -> {:ok, realm}
      nil -> {:error, :realm_not_found}
    end
  end

  @doc """
  Creates a realm.

  ## Examples

      iex> create_realm(%Cluster{}, %{field: value})
      {:ok, %Realm{}}

      iex> create_realm(%Cluster{}, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_realm(%Cluster{} = cluster, attrs \\ %{}) do
    %Realm{cluster_id: cluster.id, tenant_id: Repo.get_tenant_id()}
    |> Realm.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a realm.

  ## Examples

      iex> update_realm(realm, %{field: new_value})
      {:ok, %Realm{}}

      iex> update_realm(realm, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_realm(%Realm{} = realm, attrs) do
    realm
    |> Realm.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a realm.

  ## Examples

      iex> delete_realm(realm)
      {:ok, %Realm{}}

      iex> delete_realm(realm)
      {:error, %Ecto.Changeset{}}

  """
  def delete_realm(%Realm{} = realm) do
    Repo.delete(realm)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking realm changes.

  ## Examples

      iex> change_realm(realm)
      %Ecto.Changeset{data: %Realm{}}

  """
  def change_realm(%Realm{} = realm, attrs \\ %{}) do
    Realm.changeset(realm, attrs)
  end

  alias Edgehog.Astarte.Device

  @doc """
  Returns the list of devices.

  ## Examples

      iex> list_devices()
      [%Device{}, ...]

  """
  def list_devices do
    Repo.all(Device)
    |> Repo.preload(appliance_model: :hardware_type)
  end

  @doc """
  Gets a single device.

  Raises `Ecto.NoResultsError` if the Device does not exist.

  ## Examples

      iex> get_device!(123)
      %Device{}

      iex> get_device!(456)
      ** (Ecto.NoResultsError)

  """
  def get_device!(id) do
    Repo.get!(Device, id)
    |> Repo.preload(appliance_model: :hardware_type)
  end

  @doc """
  Creates a device.

  ## Examples

      iex> create_device(%Realm{}, %{field: value})
      {:ok, %Device{}}

      iex> create_device(%Realm{}, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_device(%Realm{} = realm, attrs \\ %{}) do
    changeset =
      %Device{realm_id: realm.id, tenant_id: Repo.get_tenant_id()}
      |> Device.changeset(attrs)

    with {:ok, device} <- Repo.insert(changeset) do
      {:ok, Repo.preload(device, appliance_model: :hardware_type)}
    end
  end

  @doc """
  Updates a device.

  ## Examples

      iex> update_device(device, %{field: new_value})
      {:ok, %Device{}}

      iex> update_device(device, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_device(%Device{} = device, attrs) do
    device
    |> Device.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a device.

  ## Examples

      iex> delete_device(device)
      {:ok, %Device{}}

      iex> delete_device(device)
      {:error, %Ecto.Changeset{}}

  """
  def delete_device(%Device{} = device) do
    Repo.delete(device)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking device changes.

  ## Examples

      iex> change_device(device)
      %Ecto.Changeset{data: %Device{}}

  """
  def change_device(%Device{} = device, attrs \\ %{}) do
    Device.changeset(device, attrs)
  end

  @doc """
  Gets a single device by its realm and device_id.

  ## Examples

      iex> fetch_realm_device(realm, "existing_device_id")
      {:ok, %Device{}}

      iex> fetch_realm_device(realm, "invalid_device_id")
      {:error, :device_not_found}

  """
  def fetch_realm_device(%Realm{id: realm_id}, device_id) do
    case Repo.get_by(Device, realm_id: realm_id, device_id: device_id) do
      %Device{} = device -> {:ok, Repo.preload(device, appliance_model: :hardware_type)}
      nil -> {:error, :device_not_found}
    end
  end

  @doc """
  Processes an event coming from a trigger.
  """
  def process_device_event(%Realm{} = realm, device_id, event, timestamp) do
    with {:ok, device} <- ensure_device_exists(realm, device_id),
         {:ok, _device} <- update_device_with_event(device, event, timestamp) do
      :ok
    else
      _ -> {:error, :cannot_process_device_event}
    end
  end

  def ensure_device_exists(%Realm{} = realm, device_id) do
    device_attrs = %{device_id: device_id, name: device_id}

    with {:error, :device_not_found} <- fetch_realm_device(realm, device_id),
         {:ok, device_attrs} <-
           populate_device_status(
             realm,
             device_attrs
           ) do
      create_device(realm, device_attrs)
    end
  end

  defp populate_device_status(%Realm{} = realm, device_attrs) do
    with {:ok, device_status} <- get_device_status(realm, device_attrs.device_id) do
      device_attrs =
        device_status
        |> Map.from_struct()
        |> Enum.into(device_attrs)

      {:ok, device_attrs}
    end
  end

  defp update_device_with_event(%Device{} = device, %{"type" => "device_connected"}, timestamp) do
    change_device(device, %{online: true, last_connection: timestamp})
    |> Repo.update()
  end

  defp update_device_with_event(%Device{} = device, %{"type" => "device_disconnected"}, timestamp) do
    change_device(device, %{online: false, last_disconnection: timestamp})
    |> Repo.update()
  end

  defp update_device_with_event(
         %Device{} = device,
         %{
           "type" => "incoming_data",
           "interface" => @appliance_info_interface,
           "path" => "/serialNumber",
           "value" => serial_number
         },
         _timestamp
       ) do
    change_device(device, %{serial_number: serial_number})
    |> Repo.update()
  end

  defp update_device_with_event(
         %Device{} = device,
         %{
           "type" => "incoming_data",
           "interface" => @appliance_info_interface,
           "path" => "/partNumber",
           "value" => part_number
         },
         _timestamp
       ) do
    change_device(device, %{part_number: part_number})
    |> Repo.update()
  end

  defp update_device_with_event(%Device{} = device, _unhandled_event, _timestamp) do
    # Just return the same device
    {:ok, device}
  end

  defp get_device_status(%Realm{} = realm, device_id) do
    with {:ok, client} <- appengine_client_from_realm(realm) do
      @device_status_module.get(client, device_id)
    end
  end

  def get_hardware_info(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      HardwareInfo.get(client, device.device_id)
    end
  end

  defp appengine_client_from_device(%Device{} = device) do
    %Device{realm: realm} = Repo.preload(device, [realm: [:cluster]], skip_tenant_id: true)

    appengine_client_from_realm(realm)
  end

  defp appengine_client_from_realm(%Realm{} = realm) do
    realm = Repo.preload(realm, [:cluster], skip_tenant_id: true)

    AppEngine.new(realm.cluster.base_api_url, realm.name, realm.private_key)
  end
end
