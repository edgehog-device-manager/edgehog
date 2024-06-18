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

defmodule Edgehog.AstarteFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.Astarte` context.
  """

  @doc """
  Generate a unique cluster name.
  """
  def unique_cluster_name, do: "cluster#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique cluster API URL.
  """
  def unique_cluster_base_api_url,
    do: "https://api-#{System.unique_integer([:positive])}.astarte.example.com"

  @doc """
  Generate a unique realm name.
  """
  def unique_realm_name, do: "realm#{System.unique_integer([:positive])}"

  @doc """
  Generate a cluster.
  """
  def cluster_fixture(opts \\ []) do
    opts
    |> Enum.into(%{
      base_api_url: unique_cluster_base_api_url(),
      name: unique_cluster_name()
    })
    |> Edgehog.Astarte.create_cluster!()
  end

  @private_key X509.PrivateKey.new_ec(:secp256r1) |> X509.PrivateKey.to_pem()

  @doc """
  Generate a realm.
  """
  def realm_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop_lazy(opts, :tenant, &Edgehog.TenantsFixtures.tenant_fixture/0)

    {cluster_id, opts} =
      Keyword.pop_lazy(opts, :cluster_id, fn -> cluster_fixture() |> Map.fetch!(:id) end)

    opts
    |> Enum.into(%{
      cluster_id: cluster_id,
      name: unique_realm_name(),
      private_key: @private_key
    })
    |> Edgehog.Astarte.create_realm!(tenant: tenant.tenant_id)
  end

  @doc """
  Generate a random device id
  """
  def random_device_id do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)

    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Generate an %Astarte.Device{}.
  """
  def astarte_device_fixture(realm, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        device_id: random_device_id(),
        name: "some name"
      })

    {:ok, device} = Edgehog.Astarte.create_device(realm, attrs)

    device
  end

  @doc """
  Returns an interface map with the given name and major (and optionally minor, which defaults to 1).

  All the other parts of the interface are fixed.
  """
  def interface_map_fixture(opts \\ []) do
    name = Keyword.get(opts, :name, "io.edgehog.devicemanager.SystemInfo")
    major = Keyword.get(opts, :major, 1)
    minor = Keyword.get(opts, :minor, 1)

    %{
      "interface_name" => name,
      "version_major" => major,
      "version_minor" => minor,
      "type" => "datastream",
      "ownership" => "device",
      "mappings" => [
        %{
          "endpoint" => "/foo",
          "type" => "integer"
        }
      ]
    }
  end

  @doc """
  Returns a trigger map with the (optional) given name and http_url.

  All the other parts of the trigger are fixed.
  """
  def trigger_map_fixture(opts \\ []) do
    name = Keyword.get(opts, :name, "edgehog-connection")
    http_url = Keyword.get(opts, :http_url, "https://api.edgehog.example/tenants/test/triggers")

    %{
      "name" => name,
      "action" => %{
        "http_url" => http_url,
        "ignore_ssl_errors" => false,
        "http_method" => "post",
        "http_static_headers" => %{}
      },
      "simple_triggers" => [
        %{
          "type" => "device_trigger",
          "on" => "device_connected"
        }
      ]
    }
  end

  def base_image_info_fixture(opts \\ []) do
    %Edgehog.Astarte.Device.BaseImage{
      name: "esp-idf",
      version: "0.1.0",
      build_id: "2022-01-01 12:00:00",
      fingerprint: "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3"
    }
    |> struct!(opts)
  end

  def battery_status_fixture(opts \\ []) do
    [
      %Edgehog.Astarte.Device.BatteryStatus.BatterySlot{
        slot: "Main slot",
        level_percentage: 80.3,
        level_absolute_error: 0.1,
        status: "Charging"
      }
      |> struct!(opts)
    ]
  end

  def network_interfaces_fixture(opts \\ []) do
    [
      %Edgehog.Astarte.Device.NetworkInterface{
        name: "enp2s0",
        mac_address: "00:aa:bb:cc:dd:ee",
        technology: "Ethernet"
      }
      |> struct!(opts)
    ]
  end

  def modem_properties_fixture(opts \\ []) do
    [
      %Edgehog.Astarte.Device.CellularConnection.ModemProperties{
        slot: "modem_1",
        apn: "company.com",
        imei: "509504877678976",
        imsi: "313460000000001"
      }
      |> struct!(opts)
    ]
  end

  def modem_status_fixture(opts \\ []) do
    [
      %Edgehog.Astarte.Device.CellularConnection.ModemStatus{
        slot: "modem_1",
        carrier: "Carrier",
        cell_id: 170_402_199,
        mobile_country_code: 310,
        mobile_network_code: 410,
        local_area_code: 35_632,
        registration_status: "Registered",
        rssi: -60,
        technology: "GSM"
      }
      |> struct!(opts)
    ]
  end

  def hardware_info_fixture(opts \\ []) do
    %Edgehog.Astarte.Device.HardwareInfo{
      cpu_architecture: "Xtensa",
      cpu_model: "ESP32",
      cpu_model_name: "Dual-core Xtensa LX6",
      cpu_vendor: "Espressif Systems",
      memory_total_bytes: 344_212
    }
    |> struct!(opts)
  end

  def os_info_fixture(opts \\ []) do
    %Edgehog.Astarte.Device.OSInfo{
      name: "esp-idf",
      version: "3.0.0"
    }
    |> struct!(opts)
  end

  def runtime_info_fixture(opts \\ []) do
    %Edgehog.Astarte.Device.RuntimeInfo{
      name: "edgehog-esp32-device",
      version: "0.1.0",
      environment: "esp-idf v4.3",
      url: "https://github.com/edgehog-device-manager/edgehog-esp32-device"
    }
    |> struct!(opts)
  end

  def storage_usage_fixture(opts \\ []) do
    [
      %Edgehog.Astarte.Device.StorageUsage.StorageUnit{
        label: "Disk 0",
        total_bytes: 348_360_704,
        free_bytes: 281_360_704
      }
      |> struct!(opts)
    ]
  end

  def system_status_fixture(opts \\ []) do
    %Edgehog.Astarte.Device.SystemStatus{
      boot_id: "1c0cf72f-8428-4838-8626-1a748df5b889",
      memory_free_bytes: 166_772,
      task_count: 12,
      uptime_milliseconds: 5785,
      timestamp: ~U[2021-11-15 11:44:57.432516Z]
    }
    |> struct!(opts)
  end

  def wifi_scan_results_fixture(opts \\ []) do
    [
      %Edgehog.Astarte.Device.WiFiScanResult{
        channel: 11,
        connected: Keyword.get(opts, :connected, true),
        essid: "MyEssid",
        mac_address: "01:23:45:67:89:ab",
        rssi: -43,
        timestamp: ~U[2021-11-15 11:44:57.432516Z]
      }
      |> struct!(opts)
    ]
  end

  @default_introspection Edgehog.Tenants.Reconciler.AstarteResources.load_interfaces()
                         |> Map.new(fn
                           %{
                             "interface_name" => name,
                             "version_major" => major,
                             "version_minor" => minor
                           } ->
                             {name, %Edgehog.Astarte.InterfaceVersion{major: major, minor: minor}}
                         end)

  def device_status_fixture(opts \\ []) do
    %Edgehog.Astarte.Device.DeviceStatus{
      attributes: %{"attribute_key" => "attribute_value"},
      groups: ["test-devices"],
      introspection: @default_introspection,
      last_connection: ~U[2021-11-15 10:44:57.432516Z],
      last_disconnection: ~U[2021-11-15 10:45:57.432516Z],
      last_seen_ip: "198.51.100.25",
      online: false
    }
    |> struct!(opts)
  end
end
