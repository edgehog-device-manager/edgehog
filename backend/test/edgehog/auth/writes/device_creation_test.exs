#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Auth.Flows.DeviceCreationTest do
  @moduledoc false
  use Edgehog.Auth.AuthzCase, async: true

  import Edgehog.DevicesFixtures

  alias Edgehog.Auth.FGAService

  test "device creation writes the correct tuples on FGA", %{tenant: tenant, realm: realm} do
    test_pid = self()

    expect(FGAService, :write, 2, fn "device:" <> first, "alias", "device:" <> second ->
      # Send alias and id, in both orders
      send(test_pid, {first, second})

      {:ok, :dontcare}
    end)

    expect(FGAService, :write, 1, fn "tenant:" <> tenant_slug, rel, obj ->
      "device:" <> device_id = obj

      assert tenant_slug == tenant.slug
      assert "tenant" = rel

      # Send the device_id to the test pid, assert later
      send(test_pid, device_id)

      {:ok, :dontcare}
    end)

    expect(FGAService, :write, 1, fn "realm:" <> realm_id, rel, obj ->
      "device:" <> device_id = obj

      assert realm_id == realm.name
      assert "realm" = rel

      # Send the device_id to the test pid, assert later
      send(test_pid, device_id)

      {:ok, :dontcare}
    end)

    device = device_fixture(tenant: tenant, realm_id: realm.id)

    {device_alias, device_id} =
      receive do
        aliased -> aliased
      end

    {^device_id, ^device_alias} =
      receive do
        aliased -> aliased
      end

    device_id1 =
      receive do
        device_id -> device_id
      end

    device_id2 =
      receive do
        device_id -> device_id
      end

    assert device_id1 == device.device_id
    assert device_id2 == device.device_id
  end
end
