#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.DeviceFetcher.CoreTest do
  @moduledoc false

  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures
  import Mox

  alias Edgehog.Astarte.Device.AvailableDevicesMock
  alias Edgehog.Astarte.Device.DeviceStatusMock
  alias Edgehog.AstarteFixtures
  alias Edgehog.Devices.Reconciler.Core

  describe "Edgehog.Devices.Reconciler.Core.reconcile/1" do
    setup do
      cluster = cluster_fixture()
      tenant = tenant_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)

      {:ok, %{tenant: tenant, realm: realm, cluster: cluster}}
    end

    test "reconciles a non existent device", %{tenant: tenant} do
      device_id = AstarteFixtures.random_device_id()

      stub(DeviceStatusMock, :get, fn _client, _device_id ->
        {:ok, device_status_fixture(%{online: true})}
      end)

      expect(AvailableDevicesMock, :get_device_list, fn _client ->
        {:ok, [device_id]}
      end)

      expect(AvailableDevicesMock, :get_device_status, fn _client, ^device_id ->
        {:ok,
         %{
           "id" => device_id,
           "connected" => true
         }}
      end)

      Core.reconcile(tenant)

      devices = Ash.read!(Edgehog.Devices.Device, tenant: tenant)

      assert [device] = devices
      assert %{device_id: ^device_id, online: true} = device
    end
  end
end
