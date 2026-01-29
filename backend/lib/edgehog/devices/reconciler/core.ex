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

defmodule Edgehog.Devices.Reconciler.Core do
  @moduledoc """
  Device reconciler core utilities.

  This module takes responsibility to reconcile a realm devices list and
  astarte's devices.
  """

  alias Astarte.Client.AppEngine
  alias Edgehog.Devices.Device

  require Logger

  @available_devices Application.compile_env(
                       :edgehog,
                       :astarte_available_devices_module,
                       Edgehog.Astarte.Device.AvailableDevices
                     )

  def reconcile(tenant) do
    tenant = Ash.load!(tenant, [realm: [cluster: :base_api_url]], tenant: tenant)
    realm = tenant.realm
    base_api_url = realm.cluster.base_api_url

    with {:ok, client} <- astarte_appengine_client(base_api_url, realm),
         {:ok, devices_stream} <- @available_devices.get_device_list(client) do
      devices_stream
      |> Stream.map(&{&1, @available_devices.get_device_status(client, &1)})
      |> Stream.reject(&api_error?(&1, realm))
      |> Stream.map(fn {_device_id, {:ok, params}} -> params end)
      |> Stream.map(&astarte_status_to_device_params(&1, realm))
      |> Stream.map(&reconcile_device(&1, tenant))
      |> Stream.reject(&db_error?(&1, realm))
      |> Stream.run()
    end
  end

  def reconcile_device(params, tenant) do
    Device
    |> Ash.Changeset.for_create(:from_astarte_data, params)
    |> Ash.create(tenant: tenant)
  end

  defp astarte_appengine_client(base_url, realm) do
    AppEngine.new(base_url, realm.name, private_key: realm.private_key)
  end

  defp astarte_status_to_device_params(status, realm) when is_map(status) do
    %{
      realm_id: Map.get(realm, :id),
      device_id: Map.get(status, "id"),
      connected: Map.get(status, "connected")
    }
  end

  defp api_error?({device_id, {:error, error}}, realm) do
    Logger.warning(
      "Error while retrieving device status information for device #{device_id}: #{inspect(error)}",
      realm: realm.name
    )

    true
  end

  defp api_error?({_device_id, {:ok, _params}}, _), do: false

  defp api_error?(other, realm) do
    Logger.warning("Strange shape appeared while filtering for errors: #{inspect(other)}",
      realm: realm.name
    )

    true
  end

  defp db_error?({:error, error}, realm) do
    Logger.warning("Database error while installing device: #{inspect(error)}", realm: realm.name)
    true
  end

  defp db_error?({:ok, _device}, _realm), do: false
end
