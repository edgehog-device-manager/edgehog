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

defmodule Edgehog.Geolocation do
  @moduledoc """
  The Geolocation context.
  """

  @enforce_keys [:latitude, :longitude, :timestamp]
  defstruct [:latitude, :longitude, :accuracy, :timestamp, :address]

  alias Edgehog.Astarte
  alias Edgehog.Astarte.Device
  alias Edgehog.Geolocation
  alias Edgehog.Repo

  @type t() :: %__MODULE__{
          latitude: float,
          longitude: float,
          accuracy: number | nil,
          address: String.t() | nil,
          timestamp: DateTime.t()
        }

  def fetch_location(%Device{} = device) do
    with {:ok, coordinates} <- fetch_device_coordinates(device) do
      address = get_address(coordinates)

      location = %Geolocation{
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        accuracy: coordinates.accuracy,
        timestamp: coordinates.timestamp,
        address: address
      }

      {:ok, location}
    end
  end

  defp fetch_device_coordinates(device) do
    with {:error, _reason} <- fetch_device_wifi_coordinates(device),
         {:error, _reason} <- fetch_device_ip_coordinates(device) do
      {:error, :device_coordinates_not_found}
    end
  end

  defp fetch_device_wifi_coordinates(device) do
    with {:ok, wifi_scan_results} <- Astarte.fetch_wifi_scan_results(device),
         {:ok, wifi_scan_results} <- filter_latest_wifi_scan_results(wifi_scan_results),
         {:ok, coordinates} <- geolocate_wifi(wifi_scan_results) do
      timestamp =
        case Enum.empty?(wifi_scan_results) do
          false -> List.first(wifi_scan_results).timestamp
          true -> DateTime.utc_now()
        end

      coordinates = Enum.into(%{timestamp: timestamp}, coordinates)

      {:ok, coordinates}
    end
  end

  defp filter_latest_wifi_scan_results([_scan | _] = wifi_scan_results) do
    latest_scan = Enum.max_by(wifi_scan_results, & &1.timestamp, DateTime)

    latest_wifi_scan_results =
      Enum.filter(wifi_scan_results, &(&1.timestamp == latest_scan.timestamp))

    {:ok, latest_wifi_scan_results}
  end

  defp filter_latest_wifi_scan_results(_wifi_scan_results) do
    {:error, :wifi_scan_results_not_found}
  end

  defp fetch_device_ip_coordinates(device) do
    device = Repo.preload(device, :realm)

    with {:ok, device_status} <- Astarte.get_device_status(device.realm, device.device_id),
         {:ok, coordinates} <- geolocate_ip(device_status.last_seen_ip) do
      device_last_seen =
        [device_status.last_connection, device_status.last_disconnection]
        |> Enum.reject(&is_nil/1)
        |> Enum.sort({:desc, DateTime})
        |> List.first()

      timestamp = device_last_seen || DateTime.utc_now()
      coordinates = Enum.into(%{timestamp: timestamp}, coordinates)

      {:ok, coordinates}
    end
  end

  defp get_address(coordinates) do
    case reverse_geocode(coordinates) do
      {:ok, address} -> address
      _ -> nil
    end
  end

  defp geolocate_ip(ip_address) do
    ip_geolocation_provider = Application.get_env(:edgehog, :ip_geolocation_provider)

    case ip_geolocation_provider do
      nil -> {:error, :ip_geolocation_provider_not_found}
      _ -> ip_geolocation_provider.geolocate(ip_address)
    end
  end

  defp geolocate_wifi(wifi_scan_results) do
    wifi_geolocation_provider = Application.get_env(:edgehog, :wifi_geolocation_provider)

    case wifi_geolocation_provider do
      nil -> {:error, :wifi_geolocation_provider_not_found}
      _ -> wifi_geolocation_provider.geolocate(wifi_scan_results)
    end
  end

  defp reverse_geocode(coordinates) do
    geocoding_provider = Application.get_env(:edgehog, :geocoding_provider)

    case geocoding_provider do
      nil -> {:error, :geocoding_provider_not_found}
      _ -> geocoding_provider.reverse_geocode(coordinates)
    end
  end
end
