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

  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures
  import Mox

  alias Edgehog.Astarte.Device.AvailableDevicesMock
  alias Edgehog.Astarte.DeviceFetcher.Core

  describe "list astarte devices/1" do
    setup do
      tenant = tenant_fixture()

      {:ok, %{tenant: tenant}}
    end

    test "list astarte devices", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)

      client = :client

      expect(AvailableDevicesMock, :get_device_list, fn _client ->
        {:ok, [device.device_id]}
      end)

      assert {:ok, devices} = Core.get_device_list(client)

      assert length(devices) == 1

      [astarte_device_id] = devices

      assert device.device_id == astarte_device_id
    end

    test "get device status", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)

      client = :client

      expected_device_id = device.device_id

      expect(AvailableDevicesMock, :get_device_status, fn _client, ^expected_device_id ->
        {:ok,
         %{
           "id" => device.device_id,
           "connected" => true
         }}
      end)

      assert {:ok, status} =
               Core.get_device_status(client, device.device_id)

      assert device.device_id == status["id"]
      assert true == status["connected"]
    end
  end
end
