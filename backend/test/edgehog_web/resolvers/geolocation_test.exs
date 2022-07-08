#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule EdgehogWeb.Resolvers.GeolocationTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase
  use Edgehog.GeolocationMockCase

  alias EdgehogWeb.Resolvers.Geolocation

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  setup do
    cluster = cluster_fixture()
    realm = realm_fixture(cluster)
    device = device_fixture(realm)

    {:ok, cluster: cluster, realm: realm, device: device}
  end

  test "fetch_device_location/3 returns the location for a device", %{
    device: device
  } do
    assert {:ok, location} = Geolocation.fetch_device_location(device, %{}, %{})

    assert %Edgehog.Geolocation{
             accuracy: 12,
             address: "4 Privet Drive, Little Whinging, Surrey, UK",
             latitude: 45.4095285,
             longitude: 11.8788231,
             timestamp: ~U[2021-11-15 11:44:57.432516Z]
           } == location
  end
end
