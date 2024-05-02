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

  alias Edgehog.Config
  alias Edgehog.Devices.Device
  alias Edgehog.Geolocation.Position

  def geolocate(%Device{} = device) do
    geolocation_providers = Config.geolocation_providers!()

    geolocate_with(geolocation_providers, device)
  end

  def reverse_geocode(%Position{} = position) do
    geocoding_providers = Config.geocoding_providers!()

    reverse_geocode_with(geocoding_providers, position)
  end

  defp geolocate_with([], %Device{} = _device) do
    {:error, :position_not_found}
  end

  defp geolocate_with([provider | other_providers], %Device{} = device) do
    with {:error, _reason} <- provider.geolocate(device) do
      geolocate_with(other_providers, device)
    end
  end

  defp reverse_geocode_with([], _position) do
    {:error, :location_not_found}
  end

  defp reverse_geocode_with([provider | other_providers], position) do
    with {:error, _reason} <- provider.reverse_geocode(position) do
      reverse_geocode_with(other_providers, position)
    end
  end
end
