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

defmodule Edgehog.Geolocation do
  @moduledoc """
  The Geolocation context.
  """

  @enforce_keys [:latitude, :longitude, :timestamp]
  defstruct [:latitude, :longitude, :accuracy, :timestamp, :address]

  alias Edgehog.Config
  alias Edgehog.Devices.Device
  alias Edgehog.Geolocation
  alias Edgehog.Geolocation.Coordinates

  @type t() :: %__MODULE__{
          latitude: float,
          longitude: float,
          accuracy: number | nil,
          address: String.t() | nil,
          timestamp: DateTime.t()
        }

  def fetch_location(%Device{} = device) do
    geolocation_providers = Config.geolocation_providers!()
    geocoding_providers = Config.geocoding_providers!()

    with {:ok, position} <- geolocate_with(geolocation_providers, device) do
      coordinates = %Coordinates{
        latitude: position.latitude,
        longitude: position.longitude
      }

      address =
        case reverse_geocode_with(geocoding_providers, coordinates) do
          {:ok, address} -> address
          _ -> nil
        end

      location = %Geolocation{
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
        address: address
      }

      {:ok, location}
    end
  end

  defp geolocate_with([], %Device{} = _device) do
    {:error, :device_position_not_found}
  end

  defp geolocate_with([provider | other_providers], %Device{} = device) do
    with {:error, _reason} <- provider.geolocate(device) do
      geolocate_with(other_providers, device)
    end
  end

  defp reverse_geocode_with([], _coordinates) do
    {:error, :device_address_not_found}
  end

  defp reverse_geocode_with([provider | other_providers], coordinates) do
    with {:error, _reason} <- provider.reverse_geocode(coordinates) do
      reverse_geocode_with(other_providers, coordinates)
    end
  end
end
