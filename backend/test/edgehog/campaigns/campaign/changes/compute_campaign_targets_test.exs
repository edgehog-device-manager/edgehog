#
# This file is part of Edgehog.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Edgehog.Campaigns.Campaign.Changes.ComputeCampaignTargetsTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.TenantsFixtures

  setup do
    tenant = tenant_fixture()
    target_group = device_group_fixture(selector: ~s<"foobar" in tags>, tenant: tenant)
    channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)
    release = release_fixture(system_models: 1, tenant: tenant)

    %{
      tenant: tenant,
      target_group: target_group,
      channel: channel,
      release: release
    }
  end

  describe "compute_campaign_targets for deployment_deploy operation" do
    test "includes all devices matching system model in the channel", %{
      tenant: tenant,
      release: release,
      channel: channel
    } do
      # Create 3 devices with matching system model
      device1 =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      device2 =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      device3 =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      # Create campaign with deploy operation
      campaign =
        campaign_fixture(
          name: "Test Deploy Campaign",
          mechanism_type: :deployment_deploy,
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      campaign = Ash.load!(campaign, :campaign_targets, tenant: tenant)

      # All 3 devices should be included as targets
      assert length(campaign.campaign_targets) == 3

      target_device_ids =
        campaign.campaign_targets |> Enum.map(& &1.device_id) |> Enum.sort()

      expected_device_ids = Enum.sort([device1.id, device2.id, device3.id])

      assert target_device_ids == expected_device_ids
    end

    test "excludes devices that don't match system model", %{
      tenant: tenant,
      release: release,
      channel: channel
    } do
      # Create a device with matching system model
      _matching_device =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      # Create a device with non-matching system model
      _non_matching_device =
        [tenant: tenant]
        |> device_fixture()
        |> add_tags(["foobar"])

      campaign =
        campaign_fixture(
          name: "Test Deploy Campaign",
          mechanism_type: :deployment_deploy,
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      campaign = Ash.load!(campaign, :campaign_targets, tenant: tenant)

      # Only the matching device should be included
      assert length(campaign.campaign_targets) == 1
    end
  end

  describe "compute_campaign_targets for deployment_start operation" do
    test "only includes devices that have the release deployed", %{
      tenant: tenant,
      release: release,
      channel: channel
    } do
      # Device 1: Has the release deployed
      device_with_deployment =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      # Create a deployment for device 1
      _deployment =
        deployment_fixture(
          device_id: device_with_deployment.id,
          release_id: release.id,
          tenant: tenant
        )

      # Device 2: Doesn't have the release deployed
      _device_without_deployment =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      # Create deployment campaign with start operation
      campaign =
        campaign_fixture(
          name: "Test Start Campaign",
          mechanism_type: :deployment_start,
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      campaign = Ash.load!(campaign, :campaign_targets, tenant: tenant)

      # Only device with deployment should be included
      assert length(campaign.campaign_targets) == 1
      assert hd(campaign.campaign_targets).device_id == device_with_deployment.id
    end

    test "creates finished campaign when no devices have the release", %{
      tenant: tenant,
      release: release,
      channel: channel
    } do
      # Create devices without deployment
      _device1 =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      _device2 =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      campaign =
        campaign_fixture(
          name: "Test Start Campaign",
          mechanism_type: :deployment_start,
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      # Campaign should be finished with success
      assert campaign.status == :finished
      assert campaign.outcome == :success

      campaign = Ash.load!(campaign, :campaign_targets, tenant: tenant)
      assert campaign.campaign_targets == []
    end
  end

  describe "compute_campaign_targets for deployment_stop operation" do
    test "only includes devices that have the release deployed", %{
      tenant: tenant,
      release: release,
      channel: channel
    } do
      device_with_deployment =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      _deployment =
        deployment_fixture(
          device_id: device_with_deployment.id,
          release_id: release.id,
          tenant: tenant
        )

      _device_without_deployment =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      campaign =
        campaign_fixture(
          name: "Test Stop Campaign",
          mechanism_type: :deployment_stop,
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      campaign = Ash.load!(campaign, :campaign_targets, tenant: tenant)

      assert length(campaign.campaign_targets) == 1
      assert hd(campaign.campaign_targets).device_id == device_with_deployment.id
    end
  end

  describe "compute_campaign_targets for deployment_delete operation" do
    test "only includes devices that have the release deployed", %{
      tenant: tenant,
      release: release,
      channel: channel
    } do
      device_with_deployment =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      _deployment =
        deployment_fixture(
          device_id: device_with_deployment.id,
          release_id: release.id,
          tenant: tenant
        )

      _device_without_deployment =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      campaign =
        campaign_fixture(
          name: "Test Delete Campaign",
          mechanism_type: :deployment_delete,
          release_id: release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      campaign = Ash.load!(campaign, :campaign_targets, tenant: tenant)

      assert length(campaign.campaign_targets) == 1
      assert hd(campaign.campaign_targets).device_id == device_with_deployment.id
    end
  end

  describe "compute_campaign_targets for deployment_upgrade operation" do
    setup %{tenant: tenant} do
      application = application_fixture(tenant: tenant)

      %{application: application}
    end

    test "only includes devices that have the release deployed", %{
      tenant: tenant,
      channel: channel,
      application: application
    } do
      release =
        release_fixture(
          application_id: application.id,
          version: "1.0.0",
          system_models: 1,
          tenant: tenant
        )

      target_release =
        release_fixture(
          application_id: application.id,
          version: "2.0.0",
          system_models: 1,
          tenant: tenant
        )

      # Device 1: Has the release deployed (should be included)
      device_with_deployment =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      _deployment =
        deployment_fixture(
          device_id: device_with_deployment.id,
          release_id: release.id,
          tenant: tenant
        )

      # Device 2: Doesn't have the release deployed (should be excluded)
      _device_without_deployment =
        [release_id: release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      campaign =
        campaign_fixture(
          name: "Test Upgrade Campaign",
          mechanism_type: :deployment_upgrade,
          release_id: release.id,
          target_release_id: target_release.id,
          channel_id: channel.id,
          tenant: tenant
        )

      campaign = Ash.load!(campaign, :campaign_targets, tenant: tenant)

      # Only device with existing deployment should be included
      assert length(campaign.campaign_targets) == 1
      assert hd(campaign.campaign_targets).device_id == device_with_deployment.id
    end

    test "excludes devices with different release deployed", %{
      tenant: tenant,
      channel: channel,
      application: application
    } do
      release_v1 =
        release_fixture(
          application_id: application.id,
          version: "1.0.0",
          system_models: 1,
          tenant: tenant
        )

      release_v2 =
        release_fixture(
          application_id: application.id,
          version: "2.0.0",
          system_models: 1,
          tenant: tenant
        )

      other_release =
        release_fixture(
          application_id: application.id,
          version: "0.5.0",
          system_models: 1,
          tenant: tenant
        )

      # Device has a different release deployed
      device_with_other_release =
        [release_id: other_release.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      _deployment =
        deployment_fixture(
          device_id: device_with_other_release.id,
          release_id: other_release.id,
          tenant: tenant
        )

      campaign =
        campaign_fixture(
          name: "Test Upgrade Campaign",
          mechanism_type: :deployment_upgrade,
          release_id: release_v1.id,
          target_release_id: release_v2.id,
          channel_id: channel.id,
          tenant: tenant
        )

      campaign = Ash.load!(campaign, :campaign_targets, tenant: tenant)

      # Device with different release should be excluded
      assert campaign.campaign_targets == []
    end
  end

  describe "compute_campaign_targets with multiple deployments" do
    setup %{tenant: tenant} do
      application = application_fixture(tenant: tenant)

      %{application: application}
    end

    test "includes device if it has the correct release among multiple deployments", %{
      tenant: tenant,
      channel: channel,
      application: application
    } do
      release1 =
        release_fixture(
          application_id: application.id,
          version: "1.0.0",
          system_models: 1,
          tenant: tenant
        )

      release2 =
        release_fixture(
          application_id: application.id,
          version: "2.0.0",
          system_models: 1,
          tenant: tenant
        )

      device =
        [release_id: release1.id, tenant: tenant]
        |> device_fixture_compatible_with_release()
        |> add_tags(["foobar"])

      # Deploy both releases to the device
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

      # Create campaign for release1 with stop operation
      campaign =
        campaign_fixture(
          name: "Test Stop Campaign",
          mechanism_type: :deployment_stop,
          release_id: release1.id,
          channel_id: channel.id,
          tenant: tenant
        )

      campaign = Ash.load!(campaign, :campaign_targets, tenant: tenant)

      # Device should be included because it has release1 deployed
      assert length(campaign.campaign_targets) == 1
      assert hd(campaign.campaign_targets).device_id == device.id
    end
  end

  describe "compute_campaign_targets for firmware_upgrade operation" do
    setup %{tenant: tenant} do
      base_image = base_image_fixture(tenant: tenant)

      %{base_image: base_image}
    end

    test "includes all devices matching system model in the channel", %{
      tenant: tenant,
      base_image: base_image,
      channel: channel
    } do
      # Create 3 devices with matching system model
      device1 =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with_base_image()
        |> add_tags(["foobar"])

      device2 =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with_base_image()
        |> add_tags(["foobar"])

      device3 =
        [base_image_id: base_image.id, tenant: tenant]
        |> device_fixture_compatible_with_base_image()
        |> add_tags(["foobar"])

      # Create campaign with deploy operation
      campaign =
        campaign_fixture(
          name: "Test Update Campaign",
          mechanism_type: :firmware_upgrade,
          base_image_id: base_image.id,
          channel_id: channel.id,
          tenant: tenant
        )

      campaign = Ash.load!(campaign, :campaign_targets, tenant: tenant)

      # All 3 devices should be included as targets
      assert length(campaign.campaign_targets) == 3

      target_device_ids =
        campaign.campaign_targets |> Enum.map(& &1.device_id) |> Enum.sort()

      expected_device_ids = Enum.sort([device1.id, device2.id, device3.id])

      assert target_device_ids == expected_device_ids
    end
  end
end
