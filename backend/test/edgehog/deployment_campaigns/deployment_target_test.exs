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

defmodule Edgehog.DeploymentCampaigns.DeploymentTargetTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DeploymentCampaignsFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.TenantsFixtures

  alias Ash.Error.Invalid
  alias Edgehog.DeploymentCampaigns

  setup do
    tenant = tenant_fixture()
    application = application_fixture(tenant: tenant)
    release = release_fixture(application_id: application.id, tenant: tenant, system_models: 1)

    tag = "test-tag-#{System.unique_integer([:positive])}"
    group = device_group_fixture(selector: ~s<"#{tag}" in tags>, tenant: tenant)
    channel = channel_fixture(target_group_ids: [group.id], tenant: tenant)

    %{
      tenant: tenant,
      application: application,
      release: release,
      tag: tag,
      group: group,
      channel: channel
    }
  end

  describe "next_valid_target_with_application_deployed" do
    test "returns target for device with application deployed", %{
      tenant: tenant,
      application: application,
      release: release,
      tag: tag,
      channel: channel
    } do
      device =
        [release_id: release.id, online: true, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags([tag])

      _deployment =
        deployment_fixture(
          device_id: device.id,
          release_id: release.id,
          tenant: tenant
        )

      campaign =
        deployment_campaign_fixture(
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      assert {:ok, target} =
               DeploymentCampaigns.fetch_next_valid_target_with_application_deployed(
                 campaign.id,
                 application.id,
                 tenant: tenant
               )

      assert target.device_id == device.id
    end

    test "does not return target for device without application deployed", %{
      tenant: tenant,
      application: application,
      release: release,
      tag: tag,
      channel: channel
    } do
      _device =
        [release_id: release.id, online: true, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags([tag])

      campaign =
        deployment_campaign_fixture(
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      assert {:error, %Invalid{}} =
               DeploymentCampaigns.fetch_next_valid_target_with_application_deployed(
                 campaign.id,
                 application.id,
                 tenant: tenant
               )
    end

    test "only returns targets with idle status", %{tenant: tenant} do
      target = target_fixture(tenant: tenant)

      campaign = Ash.load!(target, :deployment_campaign, tenant: tenant).deployment_campaign
      release = Ash.load!(campaign, :release, tenant: tenant).release
      application = Ash.load!(release, :application, tenant: tenant).application
      device = Ash.load!(target, :device, tenant: tenant).device

      _deployment =
        deployment_fixture(
          device_id: device.id,
          release_id: release.id,
          tenant: tenant
        )

      DeploymentCampaigns.mark_target_as_in_progress(target, tenant: tenant)

      assert {:error, %Invalid{}} =
               DeploymentCampaigns.fetch_next_valid_target_with_application_deployed(
                 campaign.id,
                 application.id,
                 tenant: tenant
               )
    end

    test "only returns targets for online devices", %{
      tenant: tenant,
      application: application,
      release: release,
      tag: tag,
      channel: channel
    } do
      device =
        [release_id: release.id, online: false, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags([tag])

      _deployment =
        deployment_fixture(
          device_id: device.id,
          release_id: release.id,
          tenant: tenant
        )

      campaign =
        deployment_campaign_fixture(
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      assert {:error, %Invalid{}} =
               DeploymentCampaigns.fetch_next_valid_target_with_application_deployed(
                 campaign.id,
                 application.id,
                 tenant: tenant
               )
    end

    test "filters by correct application when multiple apps are deployed", %{
      tenant: tenant,
      application: application1,
      release: release1,
      tag: tag,
      channel: channel
    } do
      application2 = application_fixture(tenant: tenant)

      release2 =
        release_fixture(application_id: application2.id, tenant: tenant, system_models: 1)

      device =
        [release_id: release1.id, online: true, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags([tag])

      _deployment1 =
        deployment_fixture(
          device_id: device.id,
          release_id: release1.id,
          tenant: tenant
        )

      _deployment2 =
        deployment_fixture(
          device_id: device.id,
          release_id: release2.id,
          tenant: tenant
        )

      campaign =
        deployment_campaign_fixture(
          release_id: release1.id,
          channel_id: channel.id,
          tenant: tenant
        )

      assert {:ok, target} =
               DeploymentCampaigns.fetch_next_valid_target_with_application_deployed(
                 campaign.id,
                 application1.id,
                 tenant: tenant
               )

      assert target.device_id == device.id

      assert {:ok, target} =
               DeploymentCampaigns.fetch_next_valid_target_with_application_deployed(
                 campaign.id,
                 application2.id,
                 tenant: tenant
               )

      assert target.device_id == device.id
    end
  end
end
