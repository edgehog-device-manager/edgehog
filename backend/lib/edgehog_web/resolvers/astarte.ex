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

defmodule EdgehogWeb.Resolvers.Astarte do
  alias Edgehog.Devices
  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device
  alias Edgehog.Astarte.Device.BatteryStatus.BatterySlot
  alias Edgehog.Geolocation

  def find_device(%{id: id}, %{context: context}) do
    device =
      Astarte.get_device!(id)
      |> preload_system_model_for_device(context)

    {:ok, device}
  end

  def list_devices(_parent, %{filter: filter}, %{context: context}) do
    devices =
      Astarte.list_devices(filter)
      |> preload_system_model_for_device(context)

    {:ok, devices}
  end

  def list_devices(_parent, _args, %{context: context}) do
    devices =
      Astarte.list_devices()
      |> preload_system_model_for_device(context)

    {:ok, devices}
  end

  defp preload_system_model_for_device(target, %{locale: locale}) do
    # Explicit locale, use that one
    descriptions_query = Devices.localized_system_model_description_query(locale)
    preload = [descriptions: descriptions_query, hardware_type: [], part_numbers: []]

    Astarte.preload_system_model_for_device(target, preload: preload)
  end

  defp preload_system_model_for_device(target, %{current_tenant: tenant}) do
    # Fallback
    %{default_locale: default_locale} = tenant
    descriptions_query = Devices.localized_system_model_description_query(default_locale)
    preload = [descriptions: descriptions_query, hardware_type: [], part_numbers: []]

    Astarte.preload_system_model_for_device(target, preload: preload)
  end

  def get_hardware_info(%Device{} = device, _args, _context) do
    Astarte.get_hardware_info(device)
  end

  def fetch_storage_usage(%Device{} = device, _args, _context) do
    case Astarte.fetch_storage_usage(device) do
      {:ok, storage_units} -> {:ok, storage_units}
      _ -> {:ok, nil}
    end
  end

  def fetch_system_status(%Device{} = device, _args, _context) do
    case Astarte.fetch_system_status(device) do
      {:ok, system_status} -> {:ok, system_status}
      _ -> {:ok, nil}
    end
  end

  def fetch_wifi_scan_results(%Device{} = device, _args, _context) do
    case Astarte.fetch_wifi_scan_results(device) do
      {:ok, wifi_scan_results} -> {:ok, wifi_scan_results}
      _ -> {:ok, nil}
    end
  end

  def fetch_device_location(%Device{} = device, _args, _context) do
    case Geolocation.fetch_location(device) do
      {:ok, location} -> {:ok, location}
      _ -> {:ok, nil}
    end
  end

  def fetch_battery_status(%Device{} = device, _args, _context) do
    case Astarte.fetch_battery_status(device) do
      {:ok, battery_status} -> {:ok, battery_status}
      _ -> {:ok, nil}
    end
  end

  def fetch_os_bundle(%Device{} = device, _args, _context) do
    case Astarte.fetch_os_bundle(device) do
      {:ok, os_bundle} -> {:ok, os_bundle}
      _ -> {:ok, nil}
    end
  end

  def fetch_os_info(%Device{} = device, _args, _context) do
    case Astarte.fetch_os_info(device) do
      {:ok, os_info} -> {:ok, os_info}
      _ -> {:ok, nil}
    end
  end

  def battery_status_to_enum(%BatterySlot{status: status}, _args, _context) do
    case status do
      "Charging" -> {:ok, :charging}
      "Discharging" -> {:ok, :discharging}
      "Idle" -> {:ok, :idle}
      "EitherIdleOrCharging" -> {:ok, :either_idle_or_charging}
      "Failure" -> {:ok, :failure}
      "Removed" -> {:ok, :removed}
      "Unknown" -> {:ok, :unknown}
      _other -> {:error, :invalid_battery_status}
    end
  end
end
