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

defmodule Edgehog.Mocks.Geolocation.IPGeolocationProvider do
  @behaviour Edgehog.Geolocation.IPGeolocationProvider

  @impl true
  def geolocate(nil = _ip_address) do
    {:error, :coordinates_not_found}
  end

  @impl true
  def geolocate(_ip_address) do
    coordinates = %{accuracy: nil, latitude: 45.4019498, longitude: 11.8706081}

    {:ok, coordinates}
  end
end
