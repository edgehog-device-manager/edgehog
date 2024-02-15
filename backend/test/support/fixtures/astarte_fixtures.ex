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
    |> Edgehog.Astarte.Cluster.create!()
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
    |> Edgehog.Astarte.Realm.create!(tenant: tenant.tenant_id)
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
      name: opts[:name] || "esp-idf",
      version: opts[:version] || "0.1.0",
      build_id: opts[:build_id] || "2022-01-01 12:00:00",
      fingerprint:
        opts[:fingerprint] || "b14c1457dc10469418b4154fef29a90e1ffb4dddd308bf0f2456d436963ef5b3"
    }
  end

  def os_info_fixture(opts \\ []) do
    %Edgehog.Astarte.Device.OSInfo{
      name: opts[:name] || "esp-idf",
      version: opts[:version] || "3.0.0"
    }
  end

  def wifi_scan_results_fixture(opts \\ []) do
    [
      %Edgehog.Astarte.Device.WiFiScanResult{
        channel: opts[:channel] || 11,
        connected: Keyword.get(opts, :connected, true),
        essid: opts[:essid] || "MyEssid",
        mac_address: opts[:mac_address] || "01:23:45:67:89:ab",
        rssi: opts[:rssi] || -43,
        timestamp: opts[:timestamp] || ~U[2021-11-15 11:44:57.432516Z]
      }
    ]
  end
end
