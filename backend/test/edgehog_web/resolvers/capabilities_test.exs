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

defmodule EdgehogWeb.Resolvers.CapabilitiesTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase
  use Edgehog.GeolocationMockCase

  alias Astarte.Client.APIError
  alias Edgehog.Astarte.Device.DeviceStatus
  alias Edgehog.Devices
  alias EdgehogWeb.Resolvers.Capabilities

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  setup do
    cluster = cluster_fixture()
    realm = realm_fixture(cluster)

    device =
      device_fixture(realm)
      |> Devices.preload_astarte_resources_for_device()

    {:ok, cluster: cluster, realm: realm, device: device}
  end

  test "list_device_capabilities/3 returns the device capabilities info for a device", %{
    device: device
  } do
    Edgehog.Astarte.Device.DeviceStatusMock
    |> expect(:get, fn _appengine_client, _device_id ->
      {:ok,
       %DeviceStatus{
         introspection: %{}
       }}
    end)

    assert {:ok, capabilities} = Capabilities.list_device_capabilities(device, %{}, %{})
    assert is_list(capabilities)
  end

  test "list_device_capabilities/3 without DeviceStatus returns empty list", %{
    device: device
  } do
    Edgehog.Astarte.Device.DeviceStatusMock
    |> expect(:get, fn _appengine_client, _device_id ->
      {:error,
       %APIError{
         status: 404,
         response: %{"errors" => %{"detail" => "Device not found"}}
       }}
    end)

    assert {:ok, []} = Capabilities.list_device_capabilities(device, %{}, %{})
  end
end
