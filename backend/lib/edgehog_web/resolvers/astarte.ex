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
  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device.BatteryStatus.BatterySlot
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

  def fetch_battery_status(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, battery_status} <- Astarte.fetch_battery_status(client, device_id) do
      {:ok, battery_status}
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

  def fetch_cellular_connection(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, modem_properties_list} <-
           Astarte.fetch_cellular_connection_properties(client, device_id) do
      modem_status_map =
        case Astarte.fetch_cellular_connection_status(client, device_id) do
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
    device =
      device_id
      |> Devices.get_device!()
      |> Devices.preload_astarte_resources_for_device()

    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, led_behavior} <- led_behavior_from_enum(behavior),
         :ok <- Astarte.send_led_behavior(client, device_id, led_behavior) do
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
