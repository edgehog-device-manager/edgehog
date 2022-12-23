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

  def fetch_network_interfaces(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, network_interfaces} <- Astarte.fetch_network_interfaces(client, device_id) do
      {:ok, network_interfaces}
    else
      _ -> {:ok, nil}
    end
  end

  def resolve_network_interface_technology(%NetworkInterface{technology: nil}, _args, _res) do
    {:ok, nil}
  end

  def resolve_network_interface_technology(%NetworkInterface{technology: technology}, _args, _res) do
    network_interface_technology_to_enum(technology)
  end

  defp network_interface_technology_to_enum("Ethernet"), do: {:ok, :ethernet}
  defp network_interface_technology_to_enum("Bluetooth"), do: {:ok, :bluetooth}
  defp network_interface_technology_to_enum("Cellular"), do: {:ok, :cellular}
  defp network_interface_technology_to_enum("WiFi"), do: {:ok, :wifi}

  defp network_interface_technology_to_enum(_),
    do: {:error, :invalid_network_interface_technology}

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

  def resolve_modem_registration_status(%{registration_status: nil}, _args, _res) do
    {:ok, nil}
  end

  def resolve_modem_registration_status(%{registration_status: registration_status}, _args, _res) do
    modem_registration_status_to_enum(registration_status)
  end

  defp modem_registration_status_to_enum("NotRegistered"), do: {:ok, :not_registered}
  defp modem_registration_status_to_enum("Registered"), do: {:ok, :registered}
  defp modem_registration_status_to_enum("SearchingOperator"), do: {:ok, :searching_operator}
  defp modem_registration_status_to_enum("RegistrationDenied"), do: {:ok, :registration_denied}
  defp modem_registration_status_to_enum("Unknown"), do: {:ok, :unknown}
  defp modem_registration_status_to_enum("RegisteredRoaming"), do: {:ok, :registered_roaming}
  defp modem_registration_status_to_enum(_), do: {:error, :invalid_modem_registration_status}

  def resolve_modem_technology(%{technology: nil}, _args, _res) do
    {:ok, nil}
  end

  def resolve_modem_technology(%{technology: technology}, _args, _res) do
    modem_technology_to_enum(technology)
  end

  defp modem_technology_to_enum("GSM"), do: {:ok, :gsm}
  defp modem_technology_to_enum("GSMCompact"), do: {:ok, :gsm_compact}
  defp modem_technology_to_enum("UTRAN"), do: {:ok, :utran}
  defp modem_technology_to_enum("GSMwEGPRS"), do: {:ok, :gsm_egprs}
  defp modem_technology_to_enum("UTRANwHSDPA"), do: {:ok, :utran_hsdpa}
  defp modem_technology_to_enum("UTRANwHSUPA"), do: {:ok, :utran_hsupa}
  defp modem_technology_to_enum("UTRANwHSDPAandHSUPA"), do: {:ok, :utran_hsdpa_hsupa}
  defp modem_technology_to_enum("EUTRAN"), do: {:ok, :eutran}
  defp modem_technology_to_enum(_), do: {:error, :invalid_modem_technology}

  def resolve_battery_status(%BatterySlot{status: nil}, _args, _res) do
    {:ok, nil}
  end

  def resolve_battery_status(%BatterySlot{status: status}, _args, _res) do
    battery_status_to_enum(status)
  end

  defp battery_status_to_enum("Charging"), do: {:ok, :charging}
  defp battery_status_to_enum("Discharging"), do: {:ok, :discharging}
  defp battery_status_to_enum("Idle"), do: {:ok, :idle}
  defp battery_status_to_enum("EitherIdleOrCharging"), do: {:ok, :either_idle_or_charging}
  defp battery_status_to_enum("Failure"), do: {:ok, :failure}
  defp battery_status_to_enum("Removed"), do: {:ok, :removed}
  defp battery_status_to_enum("Unknown"), do: {:ok, :unknown}
  defp battery_status_to_enum(_), do: {:error, :invalid_battery_status}

  def set_led_behavior(%{device_id: id, behavior: behavior}, _resolution) do
    device =
      id
      |> Devices.get_device!()
      |> Devices.preload_astarte_resources_for_device()

    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, led_behavior} <- led_behavior_from_enum(behavior),
         :ok <- Astarte.send_led_behavior(client, device.device_id, led_behavior) do
      {:ok, %{behavior: behavior}}
    end
  end

  defp led_behavior_from_enum(:blink), do: {:ok, "Blink60Seconds"}
  defp led_behavior_from_enum(:double_blink), do: {:ok, "DoubleBlink60Seconds"}
  defp led_behavior_from_enum(:slow_blink), do: {:ok, "SlowBlink60Seconds"}
  defp led_behavior_from_enum(_), do: {:error, "Unknown led behavior"}
end
