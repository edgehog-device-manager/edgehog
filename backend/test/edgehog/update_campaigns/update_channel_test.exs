#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.UpdateChannelTest do
  use Edgehog.DataCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.UpdateCampaignsFixtures

  alias Edgehog.UpdateCampaigns.UpdateChannel

  describe "updatable_devices calculation" do
    setup do
      %{tenant: Edgehog.TenantsFixtures.tenant_fixture()}
    end

    test "returns empty list without devices", %{tenant: tenant} do
      base_image = base_image_fixture(tenant: tenant)

      update_channel =
        [tenant: tenant]
        |> update_channel_fixture()
        |> Ash.load!(updatable_devices: [base_image: base_image])

      assert update_channel.updatable_devices == []
    end

    test "returns only devices matching the system model of the base image", %{tenant: tenant} do
      base_image = base_image_fixture(tenant: tenant)
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)

      device =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with()
        |> add_tags(["foobar"])

      _other_device =
        [tenant: tenant]
        |> device_fixture()
        |> add_tags(["foobar"])

      device_id = device.id

      update_channel =
        [target_group_ids: [target_group.id], tenant: tenant]
        |> update_channel_fixture()
        |> Ash.load!(updatable_devices: [base_image: base_image])

      assert [%{id: ^device_id}] = update_channel.updatable_devices
    end

    test "returns only devices belonging to the update channel with the base image", %{
      tenant: tenant
    } do
      base_image = base_image_fixture(tenant: tenant)
      target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)

      device =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with()
        |> add_tags(["foobar"])

      _other_device =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with()
        |> add_tags(["not-foobar"])

      device_id = device.id

      update_channel =
        [target_group_ids: [target_group.id], tenant: tenant]
        |> update_channel_fixture()
        |> Ash.load!(updatable_devices: [base_image: base_image])

      assert [%{id: ^device_id}] = update_channel.updatable_devices
    end

    test "returns the union of all target groups of the update channel", %{tenant: tenant} do
      base_image = base_image_fixture(tenant: tenant)
      foo_group = device_group_fixture(selector: ~s<"foo" in tags>, tenant: tenant)
      bar_group = device_group_fixture(selector: ~s<"bar" in tags>, tenant: tenant)

      foo_device =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with()
        |> add_tags(["foo"])

      bar_device =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with()
        |> add_tags(["bar"])

      update_channel =
        [target_group_ids: [foo_group.id, bar_group.id], tenant: tenant]
        |> update_channel_fixture()
        |> Ash.load!(updatable_devices: [base_image: base_image])

      updatable_device_ids = Enum.map(update_channel.updatable_devices, & &1.id)
      assert length(updatable_device_ids) == 2
      assert foo_device.id in updatable_device_ids
      assert bar_device.id in updatable_device_ids
    end

    test "deduplicates devices belonging to multiple groups", %{tenant: tenant} do
      base_image = base_image_fixture(tenant: tenant)
      foo_group = device_group_fixture(selector: ~s<"foo" in tags>, tenant: tenant)
      bar_group = device_group_fixture(selector: ~s<"bar" in tags>, tenant: tenant)

      device =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with()
        |> add_tags(["foo", "bar"])

      device_id = device.id

      update_channel =
        [target_group_ids: [foo_group.id, bar_group.id], tenant: tenant]
        |> update_channel_fixture()
        |> Ash.load!(updatable_devices: [base_image: base_image])

      assert [%{id: ^device_id}] = update_channel.updatable_devices
    end
  end
end
