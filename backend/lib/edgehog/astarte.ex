#
# This file is part of Edgehog.
#
# Copyright 2021-2022 SECO Mind Srl
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
  alias Edgehog.Astarte.InterfaceID
  alias Edgehog.Astarte.InterfaceVersion

  alias Edgehog.Astarte.Device.{
    BaseImage,
    BatteryStatus,
    CellularConnection,
    DeviceStatus,
    Geolocation,
    HardwareInfo,
    LedBehavior,
    OSInfo,
    OTARequest,
    RuntimeInfo,
    StorageUsage,
    SystemStatus,
    WiFiScanResult
  }

  @system_info_interface "io.edgehog.devicemanager.SystemInfo"

  @device_status_module Application.compile_env(
                          :edgehog,
                          :astarte_device_status_module,
                          DeviceStatus
                        )
  @storage_usage_module Application.compile_env(
                          :edgehog,
                          :astarte_storage_usage_module,
                          StorageUsage
                        )
  @wifi_scan_result_module Application.compile_env(
                             :edgehog,
                             :astarte_wifi_scan_result_module,
                             WiFiScanResult
                           )
  @system_status_module Application.compile_env(
                          :edgehog,
                          :astarte_system_status_module,
                          SystemStatus
                        )
  @battery_status_module Application.compile_env(
                           :edgehog,
                           :astarte_battery_status_module,
                           BatteryStatus
                         )
  @base_image_module Application.compile_env(:edgehog, :astarte_base_image_module, BaseImage)
  @os_info_module Application.compile_env(:edgehog, :astarte_os_info_module, OSInfo)
  @ota_request_module Application.compile_env(:edgehog, :astarte_ota_request_module, OTARequest)
  @runtime_info_module Application.compile_env(
                         :edgehog,
                         :astarte_runtime_info_module,
                         RuntimeInfo
                       )
  @cellular_connection_module Application.compile_env(
                                :edgehog,
                                :astarte_cellular_connection_module,
                                CellularConnection
                              )
  @led_behavior_module Application.compile_env(
                         :edgehog,
                         :astarte_led_behavior_module,
                         LedBehavior
                       )
  @geolocation_module Application.compile_env(:edgehog, :astarte_geolocation_module, Geolocation)

  @introspection_capability_map %{
    base_image: [
      %InterfaceID{name: "io.edgehog.devicemanager.BaseImage", major: 0, minor: 1}
    ],
    battery_status: [
      %InterfaceID{name: "io.edgehog.devicemanager.BatteryStatus", major: 0, minor: 1}
    ],
    cellular_connection: [
      %InterfaceID{
        name: "io.edgehog.devicemanager.CellularConnectionProperties",
        major: 0,
        minor: 1
      },
      %InterfaceID{name: "io.edgehog.devicemanager.CellularConnectionStatus", major: 0, minor: 1}
    ],
    commands: [
      %InterfaceID{name: "io.edgehog.devicemanager.Commands", major: 0, minor: 1}
    ],
    hardware_info: [
      %InterfaceID{name: "io.edgehog.devicemanager.HardwareInfo", major: 0, minor: 1}
    ],
    led_behaviors: [
      %InterfaceID{name: "io.edgehog.devicemanager.LedBehavior", major: 0, minor: 1}
    ],
    network_interface_info: [
      %InterfaceID{
        name: "io.edgehog.devicemanager.NetworkInterfaceProperties",
        major: 0,
        minor: 1
      }
    ],
    operating_system: [
      %InterfaceID{name: "io.edgehog.devicemanager.OSInfo", major: 0, minor: 1}
    ],
    runtime_info: [
      %InterfaceID{name: "io.edgehog.devicemanager.RuntimeInfo", major: 0, minor: 1}
    ],
    software_updates: [
      %InterfaceID{name: "io.edgehog.devicemanager.OTARequest", major: 0, minor: 1},
      %InterfaceID{name: "io.edgehog.devicemanager.OTAResponse", major: 0, minor: 1}
    ],
    storage: [
      %InterfaceID{name: "io.edgehog.devicemanager.StorageUsage", major: 0, minor: 1}
    ],
    system_info: [
      %InterfaceID{name: "io.edgehog.devicemanager.SystemInfo", major: 0, minor: 1}
    ],
    system_status: [
      %InterfaceID{name: "io.edgehog.devicemanager.SystemStatus", major: 0, minor: 1}
    ],
    telemetry_config: [
      %InterfaceID{name: "io.edgehog.devicemanager.config.Telemetry", major: 0, minor: 1}
    ],
    wifi: [
      %InterfaceID{name: "io.edgehog.devicemanager.WiFiScanResults", major: 0, minor: 1}
    ]
  }

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
  def list_devices(filters \\ %{}) do
    filters
    |> Enum.reduce(Device, &filter_with/2)
    |> Repo.all()
  end

  defp filter_with(filter, query) do
    case filter do
      {:online, online} ->
        from q in query,
          where: q.online == ^online

      {:device_id, device_id} ->
        from q in query,
          where: ilike(q.device_id, ^"%#{device_id}%")

      {:system_model_part_number, part_number} ->
        from [system_model_part_number: smpn] in ensure_system_model_part_number(query),
          where: ilike(smpn.part_number, ^"%#{part_number}%")

      {:system_model_handle, handle} ->
        from [system_model: sm] in ensure_system_model(query),
          where: ilike(sm.handle, ^"%#{handle}%")

      {:system_model_name, name} ->
        from [system_model: sm] in ensure_system_model(query),
          where: ilike(sm.name, ^"%#{name}%")

      {:hardware_type_part_number, part_number} ->
        from [hardware_type_part_number: htpn] in ensure_hardware_type_part_number(query),
          where: ilike(htpn.part_number, ^"%#{part_number}%")

      {:hardware_type_handle, handle} ->
        from [hardware_type: ht] in ensure_hardware_type(query),
          where: ilike(ht.handle, ^"%#{handle}%")

      {:hardware_type_name, name} ->
        from [hardware_type: ht] in ensure_hardware_type(query),
          where: ilike(ht.name, ^"%#{name}%")
    end
  end

  defp ensure_hardware_type(query) do
    if has_named_binding?(query, :hardware_type) do
      query
    else
      from [system_model: sm] in ensure_system_model(query),
        join: ht in assoc(sm, :hardware_type),
        as: :hardware_type
    end
  end

  defp ensure_hardware_type_part_number(query) do
    if has_named_binding?(query, :hardware_type_part_number) do
      query
    else
      from [hardware_type: ht] in ensure_hardware_type(query),
        join: htpn in assoc(ht, :part_numbers),
        as: :hardware_type_part_number
    end
  end

  defp ensure_system_model(query) do
    if has_named_binding?(query, :system_model) do
      query
    else
      from [system_model_part_number: smpn] in ensure_system_model_part_number(query),
        join: sm in assoc(smpn, :system_model),
        as: :system_model
    end
  end

  defp ensure_system_model_part_number(query) do
    if has_named_binding?(query, :system_model_part_number) do
      query
    else
      from q in query,
        join: smpn in assoc(q, :system_model_part_number),
        as: :system_model_part_number
    end
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
    %Device{realm_id: realm.id, tenant_id: Repo.get_tenant_id()}
    |> Device.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Preloads a system model for a device (or a list of devices)

  Supported options:
  - `:force` a boolean indicating if the preload has to be read from the database also if it's
  already populated. Defaults to `false`.
  - `:preload` the option passed to the preload, can be a query or a list of atoms. Defaults to `[]`.
  """
  def preload_system_model_for_device(device_or_devices, opts \\ []) do
    force = Keyword.get(opts, :force, false)
    preload = Keyword.get(opts, :preload, [])

    Repo.preload(device_or_devices, [system_model: preload], force: force)
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
    |> Device.update_changeset(attrs)
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
      %Device{} = device -> {:ok, device}
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
           "interface" => @system_info_interface,
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
           "interface" => @system_info_interface,
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

  def get_device_status(%Realm{} = realm, device_id) do
    with {:ok, client} <- appengine_client_from_realm(realm) do
      @device_status_module.get(client, device_id)
    end
  end

  def get_hardware_info(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      HardwareInfo.get(client, device.device_id)
    end
  end

  def fetch_storage_usage(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @storage_usage_module.get(client, device.device_id)
    end
  end

  def fetch_system_status(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @system_status_module.get(client, device.device_id)
    end
  end

  def fetch_geolocation(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @geolocation_module.get(client, device.device_id)
    end
  end

  def fetch_wifi_scan_results(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @wifi_scan_result_module.get(client, device.device_id)
    end
  end

  def fetch_battery_status(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @battery_status_module.get(client, device.device_id)
    end
  end

  def fetch_base_image(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @base_image_module.get(client, device.device_id)
    end
  end

  def fetch_os_info(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @os_info_module.get(client, device.device_id)
    end
  end

  def send_ota_request(%Device{} = device, uuid, url) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @ota_request_module.post(client, device.device_id, uuid, url)
    end
  end

  def fetch_cellular_connection_properties(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @cellular_connection_module.get_modem_properties(client, device.device_id)
    end
  end

  def fetch_cellular_connection_status(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @cellular_connection_module.get_modem_status(client, device.device_id)
    end
  end

  def fetch_runtime_info(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @runtime_info_module.get(client, device.device_id)
    end
  end

  def send_led_behavior(%Device{} = device, behavior) do
    with {:ok, client} <- appengine_client_from_device(device) do
      @led_behavior_module.post(client, device.device_id, behavior)
    end
  end

  # get_device_status is already called to fetch other info from the device
  # TODO implement some prefetch function so that only the first call queries AppEngine
  #      and following functions can use preloaded data
  def fetch_device_introspection(%Device{} = device) do
    with {:ok, client} <- appengine_client_from_device(device),
         {:ok, %DeviceStatus{introspection: introspection}} <-
           @device_status_module.get(client, device.device_id) do
      {:ok, introspection}
    end
  end

  defp appengine_client_from_device(%Device{} = device) do
    %Device{realm: realm} = Repo.preload(device, [realm: [:cluster]], skip_tenant_id: true)

    appengine_client_from_realm(realm)
  end

  defp appengine_client_from_realm(%Realm{} = realm) do
    realm = Repo.preload(realm, [:cluster], skip_tenant_id: true)

    AppEngine.new(realm.cluster.base_api_url, realm.name, private_key: realm.private_key)
  end

  def get_device_capabilities(introspection) do
    capabilities =
      Enum.reduce(@introspection_capability_map, [], fn {capability, interface_list}, acc ->
        if interfaces_supported?(introspection, interface_list) do
          [capability | acc]
        else
          acc
        end
      end)

    # TODO add checks on device privacy settings and geolocation providers
    [:geolocation | capabilities]
  end

  defp interfaces_supported?(introspection, interfaces) do
    Enum.all?(interfaces, &interface_supported?(introspection, &1))
  end

  defp interface_supported?(introspection, %InterfaceID{} = interface) do
    case Map.fetch(introspection, interface.name) do
      {:ok, %InterfaceVersion{major: major, minor: minor}} ->
        major == interface.major && minor >= interface.minor

      _ ->
        false
    end
  end
end
