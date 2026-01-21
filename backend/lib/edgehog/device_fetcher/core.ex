#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Astarte.DeviceFetcher.Core do
  @moduledoc false

  alias Astarte.Client.AppEngine
  alias Edgehog.Devices.Device

  @available_devices Application.compile_env(
                       :edgehog,
                       :astarte_available_devices_module,
                       Edgehog.Astarte.Device.AvailableDevices
                     )

  @spec get_device_list(term()) :: {:ok, list(String.t())} | {:error, term()}
  def get_device_list(client) do
    @available_devices.get_device_list(client)
  end

  @spec get_device_status(term(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_device_status(client, device_id) when is_binary(device_id) do
    @available_devices.get_device_status(client, device_id)
  end

  def fetch_device_from_astarte(realm, tenant) do
    realm = Ash.load!(realm, [cluster: [:base_api_url]], tenant: tenant)

    with {:ok, client} <- astarte_appengine_client(realm.cluster.base_api_url, realm),
         {:ok, devices} <- get_device_list(client) do
      fetch_statuses(devices, client, realm, tenant, [])
    end
  end

  def fetch_statuses([], _client, _realm, _tenant, acc), do: {:ok, acc}

  def fetch_statuses([device | rest], client, realm, tenant, acc) do
    {:ok, status} = get_device_status(client, device)
    params = astarte_status_to_device_params(status, realm)

    {:ok, device_record} =
      Device
      |> Ash.Changeset.for_create(:from_astarte_data, params)
      |> Ash.create(tenant: tenant)

    fetch_statuses(rest, client, realm, tenant, [device_record | acc])
  end

  @doc false
  defp astarte_appengine_client(base_url, realm) do
    AppEngine.new(base_url, realm.name, private_key: realm.private_key)
  end

  @doc false
  defp astarte_status_to_device_params(status, realm) when is_map(status) do
    %{
      realm_id: Map.get(realm, :id),
      device_id: Map.get(status, "id"),
      connected: Map.get(status, "connected")
    }
  end
end
