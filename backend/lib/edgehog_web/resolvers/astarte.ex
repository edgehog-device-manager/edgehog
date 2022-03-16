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
# SPDX-License-Identifier: Apache-2.0
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

  def update_device(%{device_id: id} = attrs, %{context: context}) do
    device = Astarte.get_device!(id)

    with {:ok, device} <- Astarte.update_device(device, attrs) do
      device = preload_system_model_for_device(device, context)
      {:ok, %{device: device}}
    end
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

  def list_device_capabilities(%Device{} = device, _args, _context) do
    with {:ok, introspection} <- Astarte.fetch_device_introspection(device),
         capabilities = Astarte.get_device_capabilities(introspection) do
      {:ok, capabilities}
    else
      _ -> {:ok, []}
    end
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

  def fetch_base_image(%Device{} = device, _args, _context) do
    case Astarte.fetch_base_image(device) do
      {:ok, base_image} -> {:ok, base_image}
      _ -> {:ok, nil}
    end
  end

  def fetch_os_info(%Device{} = device, _args, _context) do
    case Astarte.fetch_os_info(device) do
      {:ok, os_info} -> {:ok, os_info}
      _ -> {:ok, nil}
    end
  end

  def fetch_runtime_info(%Device{} = device, _args, _context) do
    case Astarte.fetch_runtime_info(device) do
      {:ok, runtime_info} -> {:ok, runtime_info}
      _ -> {:ok, nil}
    end
  end

  def fetch_cellular_connection(%Device{} = device, _args, _context) do
    with {:ok, modem_properties_list} <- Astarte.fetch_cellular_connection_properties(device) do
      modem_status_map =
        case Astarte.fetch_cellular_connection_status(device) do
          {:ok, modem_status_list} ->
            Map.new(modem_status_list, &{&1.slot, &1})

          _ ->
            %{}
        end

      cellular_connection =
        Enum.map(modem_properties_list, fn modem_properties ->
          modem_status = Map.get(modem_status_map, modem_properties.slot, %{})

          %{
            slot: modem_properties.slot,
            apn: modem_properties.apn,
            imei: modem_properties.imei,
            imsi: modem_properties.imsi,
            carrier: Map.get(modem_status, :carrier),
            cell_id: Map.get(modem_status, :cell_id),
            mobile_country_code: Map.get(modem_status, :mobile_country_code),
            mobile_network_code: Map.get(modem_status, :mobile_network_code),
            local_area_code: Map.get(modem_status, :local_area_code),
            registration_status: Map.get(modem_status, :registration_status),
            rssi: Map.get(modem_status, :rssi),
            technology: Map.get(modem_status, :technology)
          }
        end)

      {:ok, cellular_connection}
    else
      _ -> {:ok, nil}
    end
  end

  def modem_registration_status_to_enum(
        %{registration_status: registration_status},
        _args,
        _context
      ) do
    case registration_status do
      "NotRegistered" -> {:ok, :not_registered}
      "Registered" -> {:ok, :registered}
      "SearchingOperator" -> {:ok, :searching_operator}
      "RegistrationDenied" -> {:ok, :registration_denied}
      "Unknown" -> {:ok, :unknown}
      "RegisteredRoaming" -> {:ok, :registered_roaming}
      nil -> {:ok, nil}
      _other -> {:error, :invalid_modem_registration_status}
    end
  end

  def modem_technology_to_enum(
        %{technology: technology},
        _args,
        _context
      ) do
    case technology do
      "GSM" -> {:ok, :gsm}
      "GSMCompact" -> {:ok, :gsm_compact}
      "UTRAN" -> {:ok, :utran}
      "GSMwEGPRS" -> {:ok, :gsm_egprs}
      "UTRANwHSDPA" -> {:ok, :utran_hsdpa}
      "UTRANwHSUPA" -> {:ok, :utran_hsupa}
      "UTRANwHSDPAandHSUPA" -> {:ok, :utran_hsdpa_hsupa}
      "EUTRAN" -> {:ok, :eutran}
      nil -> {:ok, nil}
      _other -> {:error, :invalid_modem_technology}
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

  def set_led_behavior(%{device_id: device_id, behavior: behavior}, _resolution) do
    device = Astarte.get_device!(device_id)

    with {:ok, led_behavior} <- led_behavior_from_enum(behavior),
         :ok <- Astarte.send_led_behavior(device, led_behavior) do
      {:ok, %{behavior: behavior}}
    end
  end

  defp led_behavior_from_enum(behavior) do
    case behavior do
      :blink -> {:ok, "Blink60Seconds"}
      :double_blink -> {:ok, "DoubleBlink60Seconds"}
      :slow_blink -> {:ok, "SlowBlink60Seconds"}
      _ -> {:error, "Unknown led behavior"}
    end
  end
end
