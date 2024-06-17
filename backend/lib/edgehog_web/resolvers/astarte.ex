#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Resolvers.Astarte do
  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device.BatteryStatus.BatterySlot
  alias Edgehog.Astarte.Device.NetworkInterface
  alias Edgehog.Devices
  alias Edgehog.Devices.Device

  def fetch_hardware_info(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, hardware_info} <- Astarte.fetch_hardware_info(client, device_id) do
      {:ok, hardware_info}
    else
      _ -> {:ok, nil}
    end
  end

  def fetch_storage_usage(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, storage_units} <- Astarte.fetch_storage_usage(client, device_id) do
      {:ok, storage_units}
    else
      _ -> {:ok, nil}
    end
  end

  def fetch_system_status(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, system_status} <- Astarte.fetch_system_status(client, device_id) do
      {:ok, system_status}
    else
      _ -> {:ok, nil}
    end
  end

  def fetch_wifi_scan_results(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, wifi_scan_results} <- Astarte.fetch_wifi_scan_results(client, device_id) do
      {:ok, wifi_scan_results}
    else
      _ -> {:ok, nil}
    end
  end

  def fetch_base_image(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, base_image} <- Astarte.fetch_base_image(client, device_id) do
      {:ok, base_image}
    else
      _ -> {:ok, nil}
    end
  end

  def fetch_os_info(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, os_info} <- Astarte.fetch_os_info(client, device_id) do
      {:ok, os_info}
    else
      _ -> {:ok, nil}
    end
  end

  def fetch_runtime_info(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, runtime_info} <- Astarte.fetch_runtime_info(client, device_id) do
      {:ok, runtime_info}
    else
      _ -> {:ok, nil}
    end
  end
end
