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

defmodule Edgehog.Mocks.Geolocation.GeocodingProvider do
  @behaviour Edgehog.Geolocation.GeocodingProvider

  @impl true
  def reverse_geocode(%{latitude: _latitude, longitude: _longitude}) do
    address = "4 Privet Drive, Little Whinging, Surrey, UK"

    {:ok, address}
  end

  @impl true
  def reverse_geocode(_invalid_coordinates) do
    {:error, :address_not_found}
  end
end
