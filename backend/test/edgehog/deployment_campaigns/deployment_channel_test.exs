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

defmodule Edgehog.DeploymentCampaigns.DeploymentChannelTest do
  @moduledoc false

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DeploymentCampaignsFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  describe "updatable_devices calculation" do
    setup do
      %{tenant: Edgehog.TenantsFixtures.tenant_fixture()}
    end

    test "returns empty list without devices", %{tenant: tenant} do
      release = release_fixture(tenant: tenant)

      deployment_channel =
        [tenant: tenant]
        |> deployment_channel_fixture()
        |> Ash.load!(deployable_devices: [release: release])

      assert [] = deployment_channel.deployable_devices
    end

    test "returns only devices matching the system model of the release", %{tenant: tenant} do
      release = release_fixture(tenant: tenant, system_models: 1)
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)

      device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      _other_device =
        [tenant: tenant]
        |> device_fixture()
        |> add_tags(["foobar"])

      device_id = device.id

      deployment_channel =
        [target_group_ids: [target_group.id], tenant: tenant]
        |> deployment_channel_fixture()
        |> Ash.load!(deployable_devices: [release: release])

      assert [%{id: ^device_id}] = deployment_channel.deployable_devices
    end

    test "returns only devices belonging to the deployment channel with the release", %{
      tenant: tenant
    } do
      release = release_fixture(tenant: tenant, system_models: 1)
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)

      device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      _other_device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["not-foobar"])

      device_id = device.id

      deployment_channel =
        [target_group_ids: [target_group.id], tenant: tenant]
        |> deployment_channel_fixture()
        |> Ash.load!(deployable_devices: [release: release])

      assert [%{id: ^device_id}] = deployment_channel.deployable_devices
    end

    test "returns the union of all target groups of the update channel", %{tenant: tenant} do
      release = release_fixture(tenant: tenant, system_models: 1)
      foo_group = device_group_fixture(selector: ~s<"foo" in tags>, tenant: tenant)
      bar_group = device_group_fixture(selector: ~s<"bar" in tags>, tenant: tenant)

      foo_device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foo"])

      bar_device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["bar"])

      deployment_channel =
        [target_group_ids: [foo_group.id, bar_group.id], tenant: tenant]
        |> deployment_channel_fixture()
        |> Ash.load!(deployable_devices: [release: release])

      deployable_device_ids = Enum.map(deployment_channel.deployable_devices, & &1.id)
      assert length(deployable_device_ids) == 2
      assert foo_device.id in deployable_device_ids
      assert bar_device.id in deployable_device_ids
    end

    test "deduplicates devices belonging to multiple groups", %{tenant: tenant} do
      release = release_fixture(tenant: tenant, system_models: 1)
      foo_group = device_group_fixture(selector: ~s<"foo" in tags>, tenant: tenant)
      bar_group = device_group_fixture(selector: ~s<"bar" in tags>, tenant: tenant)

      device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foo", "bar"])

      device_id = device.id

      deployment_channel =
        [target_group_ids: [foo_group.id, bar_group.id], tenant: tenant]
        |> deployment_channel_fixture()
        |> Ash.load!(deployable_devices: [release: release])

      assert [%{id: ^device_id}] = deployment_channel.deployable_devices
    end
  end
end
