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

defmodule Edgehog.CampaignsFixtures do
  @moduledoc """
  Test fixtures for the Campaigns domain.

  This module provides fixtures for creating campaigns, channels, and targets
  with support for all campaign mechanism types:

  - `:firmware_upgrade` - Firmware upgrade campaigns (OTA updates)
  - `:deployment_deploy` - Deploy a new release to devices
  - `:deployment_start` - Start stopped deployments
  - `:deployment_stop` - Stop running deployments
  - `:deployment_upgrade` - Upgrade existing deployments to a new release
  - `:deployment_delete` - Delete deployments
  """

  alias Edgehog.AstarteFixtures
  alias Edgehog.BaseImagesFixtures
  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.CampaignMechanism.Core, as: MechanismCore
  alias Edgehog.Campaigns.CampaignTarget
  alias Edgehog.Campaigns.Channel
  alias Edgehog.Containers.Release
  alias Edgehog.ContainersFixtures
  alias Edgehog.DevicesFixtures
  alias Edgehog.GroupsFixtures
  alias Edgehog.OSManagement

  require Ash.Query

  # Campaign Mechanism Types

  @deployment_mechanism_types [
    :deployment_deploy,
    :deployment_start,
    :deployment_stop,
    :deployment_upgrade,
    :deployment_delete
  ]

  @firmware_mechanism_types [:firmware_upgrade]

  @all_mechanism_types @deployment_mechanism_types ++ @firmware_mechanism_types

  @doc """
  Returns all supported campaign mechanism types.
  """
  def all_mechanism_types, do: @all_mechanism_types

  @doc """
  Returns all deployment-related mechanism types.
  """
  def deployment_mechanism_types, do: @deployment_mechanism_types

  @doc """
  Returns all firmware-related mechanism types.
  """
  def firmware_mechanism_types, do: @firmware_mechanism_types

  @doc """
  Returns true if the mechanism type is deployment-related.
  """
  def deployment_mechanism?(type), do: type in @deployment_mechanism_types

  @doc """
  Returns true if the mechanism type is firmware-related.
  """
  def firmware_mechanism?(type), do: type in @firmware_mechanism_types

  # Unique Value Generators

  @doc """
  Generate a unique channel handle.
  """
  def unique_channel_handle, do: "some-handle#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique channel name.
  """
  def unique_channel_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique campaign name.
  """
  def unique_campaign_name, do: "some name#{System.unique_integer([:positive])}"

  # Channel Fixtures

  @doc """
  Generate a channel.

  ## Options

    * `:tenant` - Required. The tenant for the channel.
    * `:target_group_ids` - List of device group IDs to target. Defaults to creating a new group.
    * `:handle` - The channel handle. Defaults to a unique handle.
    * `:name` - The channel name. Defaults to a unique name.
  """
  def channel_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {target_group_ids, opts} =
      Keyword.pop_lazy(opts, :target_group_ids, fn ->
        target_group = GroupsFixtures.device_group_fixture(tenant: tenant)
        [target_group.id]
      end)

    params =
      Enum.into(opts, %{
        handle: unique_channel_handle(),
        name: unique_channel_name(),
        target_group_ids: target_group_ids
      })

    Channel
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  # Generic Campaign Fixtures

  @doc """
  Generate a campaign with the specified mechanism type.

  This is the primary fixture for creating campaigns and supports all mechanism types.
  Use the `:mechanism_type` option to specify the campaign type.

  ## Options

    * `:tenant` - Required. The tenant for the campaign.
    * `:mechanism_type` - The type of campaign mechanism. Defaults to `:deployment_deploy`.
    * `:channel_id` - The channel ID. Defaults to creating a new channel.
    * `:release_id` - For deployment campaigns. Defaults to creating a new release.
    * `:target_release_id` - For `:deployment_upgrade` campaigns. The target release to upgrade to.
    * `:base_image_id` - For `:firmware_upgrade` campaigns. Defaults to creating a new base image.
    * `:campaign_mechanism` - Additional mechanism options to override defaults.
    * `:name` - The campaign name. Defaults to a unique name.

  ## Mechanism Defaults

  All mechanisms include these defaults:
    * `max_failure_percentage: 50.0`
    * `max_in_progress_operations: 100`
  """
  def campaign_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {mechanism_type, opts} = Keyword.pop(opts, :mechanism_type, :deployment_deploy)
    {deploy_for_required_operations, opts} = Keyword.pop(opts, :deploy_for_required_operations)

    {channel_id, opts} =
      Keyword.pop_lazy(opts, :channel_id, fn ->
        [tenant: tenant] |> channel_fixture() |> Map.fetch!(:id)
      end)

    {campaign_mechanism_opts, opts} = Keyword.pop(opts, :campaign_mechanism, [])

    campaign_mechanism_opts =
      build_campaign_mechanism(mechanism_type, tenant, opts, campaign_mechanism_opts)

    if deploy_for_required_operations do
      deploy_for_required_operations(
        mechanism_type,
        Map.get(campaign_mechanism_opts, :release_id, nil),
        channel_id,
        tenant
      )
    end

    opts = Keyword.drop(opts, [:release_id, :target_release_id, :base_image_id])

    params =
      Enum.into(opts, %{
        name: unique_campaign_name(),
        channel_id: channel_id,
        campaign_mechanism: campaign_mechanism_opts
      })

    Campaign
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generate a campaign with N targets.

  Creates the specified number of devices compatible with the campaign
  and automatically assigns them to the campaign via the channel's target groups.

  ## Options

    * `:tenant` - Required. The tenant for the campaign.
    * `:mechanism_type` - The type of campaign mechanism. Defaults to `:deployment_deploy`.
    * `:tag` - The tag used for device group matching. Defaults to `"foo"`.
  """
  def campaign_with_targets_fixture(target_count, opts \\ []) when is_integer(target_count) and target_count > 0 do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {mechanism_type, opts} = Keyword.pop(opts, :mechanism_type, :deployment_deploy)
    {tag, opts} = Keyword.pop(opts, :tag, "foo")

    # Create the resource (release or base_image) based on mechanism type
    {resource_opts, opts} = prepare_campaign_resource(mechanism_type, tenant, opts)

    group = GroupsFixtures.device_group_fixture(selector: ~s<"#{tag}" in tags>, tenant: tenant)
    channel = channel_fixture(target_group_ids: [group.id], tenant: tenant)

    for _ <- 1..target_count do
      create_compatible_device(mechanism_type, resource_opts, tag, tenant)
    end

    opts
    |> Keyword.merge(resource_opts)
    |> Keyword.merge(
      channel_id: channel.id,
      mechanism_type: mechanism_type,
      tenant: tenant
    )
    |> campaign_fixture()
  end

  # Target Fixtures

  @doc """
  Generate an idle campaign target.

  Creates a campaign with a single target device in the idle state.

  ## Options

    * `:tenant` - Required. The tenant for the target.
    * `:mechanism_type` - The type of campaign mechanism. Defaults to `:deployment_deploy`.
    * `:tag` - The tag used for device group matching. Defaults to `"foo"`.
    * All other options are passed to the campaign fixture.

  ## Examples

      target_fixture(tenant: tenant)
      target_fixture(tenant: tenant, mechanism_type: :firmware_upgrade)
  """
  def target_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {mechanism_type, opts} = Keyword.pop(opts, :mechanism_type, :deployment_deploy)
    {tag, opts} = Keyword.pop(opts, :tag, "foo")

    # Create the resource (release or base_image) based on mechanism type
    {resource_opts, opts} = prepare_campaign_resource(mechanism_type, tenant, opts)

    {group_id, opts} =
      Keyword.pop_lazy(opts, :device_group_id, fn ->
        [selector: ~s<"#{tag}" in tags>, tenant: tenant]
        |> GroupsFixtures.device_group_fixture()
        |> Map.fetch!(:id)
      end)

    {channel_id, opts} =
      Keyword.pop_lazy(opts, :channel_id, fn ->
        [target_group_ids: [group_id], tenant: tenant]
        |> channel_fixture()
        |> Map.fetch!(:id)
      end)

    _ = create_compatible_device(mechanism_type, resource_opts, tag, tenant)

    campaign =
      opts
      |> Keyword.merge(resource_opts)
      |> Keyword.merge(
        channel_id: channel_id,
        mechanism_type: mechanism_type,
        tenant: tenant
      )
      |> campaign_fixture()

    campaign_id = campaign.id

    CampaignTarget
    |> Ash.Query.filter(campaign_id == ^campaign_id)
    |> Ash.read_one!(tenant: tenant, not_found_error?: true)
  end

  @doc """
  Generate an in-progress campaign target.

  Creates a target and starts the operation (deployment or OTA update).

  ## Options

    * `:tenant` - Required. The tenant for the target.
    * `:mechanism_type` - The type of campaign mechanism. Defaults to `:deployment_deploy`.
    * `:now` - The timestamp for the operation. Defaults to `DateTime.utc_now()`.
  """
  def in_progress_target_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {mechanism_type, opts} = Keyword.pop(opts, :mechanism_type, :deployment_deploy)
    {now, opts} = Keyword.pop(opts, :now, DateTime.utc_now())

    setup_operation_mocks(mechanism_type)

    target =
      opts
      |> Keyword.merge(tenant: tenant, mechanism_type: mechanism_type)
      |> target_fixture()
      |> load_target_for_operation(mechanism_type)

    target
    |> Campaigns.update_target_latest_attempt!(now)
    |> start_target_operation(mechanism_type, tenant)
  end

  @doc """
  Generate a successful (completed) campaign target.

  Creates a target, starts the operation, and marks it as successful.

  ## Options

    * `:tenant` - Required. The tenant for the target.
    * `:mechanism_type` - The type of campaign mechanism. Defaults to `:deployment_deploy`.
    * `:now` - The timestamp for completion. Defaults to `DateTime.utc_now()`.
  """
  def successful_target_fixture(opts \\ []) do
    terminated_target_fixture(opts, :success)
  end

  @doc """
  Generate a failed campaign target.

  Creates a target, starts the operation, and marks it as failed.

  ## Options

    * `:tenant` - Required. The tenant for the target.
    * `:mechanism_type` - The type of campaign mechanism. Defaults to `:deployment_deploy`.
    * `:now` - The timestamp for completion. Defaults to `DateTime.utc_now()`.
  """
  def failed_target_fixture(opts \\ []) do
    terminated_target_fixture(opts, :failure)
  end

  # Campaign Mechanism Helpers

  defp build_campaign_mechanism(mechanism_type, tenant, opts, mechanism_opts)
       when mechanism_type in @deployment_mechanism_types do
    release_id = get_release_id(mechanism_type, tenant, opts)

    base_opts = %{
      type: to_string(mechanism_type),
      release_id: release_id,
      max_failure_percentage: 50.0,
      max_in_progress_operations: 100
    }

    opts = opts ++ [release_id: release_id]

    base_opts =
      if mechanism_type == :deployment_upgrade do
        target_release_id = get_target_release_id(tenant, opts)
        Map.put(base_opts, :target_release_id, target_release_id)
      else
        base_opts
      end

    Enum.into(mechanism_opts, base_opts)
  end

  defp build_campaign_mechanism(:firmware_upgrade, tenant, opts, mechanism_opts) do
    {base_image_id, _opts} =
      Keyword.pop_lazy(opts, :base_image_id, fn ->
        [tenant: tenant] |> BaseImagesFixtures.base_image_fixture() |> Map.fetch!(:id)
      end)

    base_opts = %{
      type: "firmware_upgrade",
      base_image_id: base_image_id,
      max_failure_percentage: 50.0,
      max_in_progress_operations: 100
    }

    Enum.into(mechanism_opts, base_opts)
  end

  defp get_release_id(_mechanism_type, tenant, opts) do
    # Always create at least 1 system model to ensure compatible devices can be created
    Keyword.get_lazy(opts, :release_id, fn ->
      [tenant: tenant, system_models: 1]
      |> ContainersFixtures.release_fixture()
      |> Map.fetch!(:id)
    end)
  end

  defp get_target_release_id(tenant, opts) do
    release_id = Keyword.fetch!(opts, :release_id)

    release =
      Release
      |> Ash.get!(release_id, tenant: tenant)
      |> Ash.load!([:application, :system_models], tenant: tenant)

    required_system_models = Map.get(release, :system_models, [])

    # Parse the current version and create a higher version
    current_version = Version.parse!(release.version)

    target_version =
      "#{current_version.major}.#{current_version.minor}.#{current_version.patch + 1}"

    Keyword.get_lazy(opts, :target_release_id, fn ->
      [
        tenant: tenant,
        required_system_models: required_system_models,
        version: target_version,
        application_id: release.application.id
      ]
      |> ContainersFixtures.release_fixture()
      |> Map.fetch!(:id)
    end)
  end

  # Resource Preparation Helpers

  defp prepare_campaign_resource(mechanism_type, tenant, opts) when mechanism_type in @deployment_mechanism_types do
    # Always create at least 1 system model to ensure compatible devices can be created
    {release_id, opts} =
      Keyword.pop_lazy(opts, :release_id, fn ->
        [tenant: tenant, system_models: 1]
        |> ContainersFixtures.release_fixture()
        |> Map.fetch!(:id)
      end)

    resource_opts = [release_id: release_id]

    resource_opts =
      if mechanism_type == :deployment_upgrade do
        target_release_id = get_target_release_id(tenant, opts ++ resource_opts)
        Keyword.put(resource_opts, :target_release_id, target_release_id)
      else
        resource_opts
      end

    {resource_opts, Keyword.delete(opts, :target_release_id)}
  end

  defp prepare_campaign_resource(:firmware_upgrade, tenant, opts) do
    {base_image_id, opts} =
      Keyword.pop_lazy(opts, :base_image_id, fn ->
        [tenant: tenant] |> BaseImagesFixtures.base_image_fixture() |> Map.fetch!(:id)
      end)

    {[base_image_id: base_image_id], opts}
  end

  defp deploy_for_required_operations(mechanism_type, release_id, channel_id, tenant) do
    if mechanism_type in [
         :deployment_start,
         :deployment_stop,
         :deployment_delete,
         :deployment_upgrade
       ] do
      release = Ash.get!(Release, release_id, tenant: tenant)

      deployable_devices =
        Channel
        |> Ash.get!(channel_id, tenant: tenant)
        |> Ash.load!(deployable_devices: [release: release])
        |> Map.get(:deployable_devices)

      Enum.each(deployable_devices, fn device ->
        deployment =
          [device_id: device.id, release_id: release.id, tenant: tenant]
          |> ContainersFixtures.deployment_fixture()
          |> Ash.load!(
            container_deployments: [
              :device_mapping_deployments,
              :network_deployments,
              :volume_deployments
            ]
          )

        # We set the state of deployment to one of ready states, so the overall deployment is ready
        fake_deployment_readiness(deployment, mechanism_type, tenant)
      end)
    end
  end

  # Device Creation Helpers

  # For deployment_deploy, we just need a compatible device (no existing deployment)
  defp create_compatible_device(:deployment_deploy, resource_opts, tag, tenant) do
    resource_opts
    |> Keyword.merge(online: true, tenant: tenant)
    |> DevicesFixtures.device_fixture_compatible_with_release()
    |> DevicesFixtures.add_tags([tag])
  end

  # For start/stop/delete/upgrade, the device must already have the release deployed
  defp create_compatible_device(mechanism_type, resource_opts, tag, tenant)
       when mechanism_type in [:deployment_start, :deployment_stop, :deployment_delete, :deployment_upgrade] do
    release_id = Keyword.fetch!(resource_opts, :release_id)

    resource_opts = Keyword.delete(resource_opts, :target_release_id)

    device =
      resource_opts
      |> Keyword.merge(online: true, tenant: tenant)
      |> DevicesFixtures.device_fixture_compatible_with_release()
      |> DevicesFixtures.add_tags([tag])

    # Deploy the release to the device so it can be targeted by these operations
    deployment =
      [device_id: device.id, release_id: release_id, tenant: tenant]
      |> ContainersFixtures.deployment_fixture()
      |> Ash.load!(
        container_deployments: [
          :device_mapping_deployments,
          :network_deployments,
          :volume_deployments
        ]
      )

    # We set the state of deployment to one of ready states, so the overall deployment is ready
    fake_deployment_readiness(deployment, mechanism_type, tenant)

    device
  end

  defp create_compatible_device(:firmware_upgrade, resource_opts, tag, tenant) do
    resource_opts
    |> Keyword.merge(online: true, tenant: tenant)
    |> DevicesFixtures.device_fixture_compatible_with_base_image()
    |> DevicesFixtures.add_tags([tag])
  end

  defp fake_deployment_readiness(deployment, mechanism_type, tenant) do
    Enum.each(deployment.container_deployments, fn cd ->
      Ash.bulk_update!(
        cd.device_mapping_deployments,
        :set_state,
        %{state: :present},
        tenant: tenant
      )

      Ash.bulk_update!(
        cd.network_deployments,
        :set_state,
        %{state: :available},
        tenant: tenant
      )

      Ash.bulk_update!(
        cd.volume_deployments,
        :set_state,
        %{state: :available},
        tenant: tenant
      )
    end)

    if mechanism_type == :deployment_stop do
      Edgehog.Containers.mark_deployment_as_started(deployment, tenant: tenant)
    else
      Edgehog.Containers.mark_deployment_as_stopped(deployment, tenant: tenant)
    end
  end

  # Mock Setup Helpers

  defp setup_operation_mocks(mechanism_type) when mechanism_type in @deployment_mechanism_types do
    Mox.stub(
      Edgehog.Astarte.Device.CreateDeploymentRequestMock,
      :send_create_deployment_request,
      fn _client, _device_id, _data -> :ok end
    )
  end

  defp setup_operation_mocks(:firmware_upgrade) do
    Mox.stub(Edgehog.Astarte.Device.BaseImageMock, :get, fn _client, _device_id ->
      {:ok, AstarteFixtures.base_image_info_fixture()}
    end)

    Mox.stub(Edgehog.Astarte.Device.DeviceStatusMock, :get, fn _client, _device_id ->
      {:ok, AstarteFixtures.device_status_fixture()}
    end)

    Mox.stub(
      Edgehog.Astarte.Device.OTARequestV1Mock,
      :update,
      fn _client, _device_id, _uuid, _url -> :ok end
    )
  end

  # Target Loading Helpers

  defp load_target_for_operation(target, mechanism_type) when mechanism_type in @deployment_mechanism_types do
    Ash.load!(target, deployment: [:state], device: [realm: [:cluster]])
  end

  defp load_target_for_operation(target, :firmware_upgrade) do
    Ash.load!(target, ota_operation: [:status], device: [realm: [:cluster]])
  end

  # Operation Starting Helpers

  defp start_target_operation(target, mechanism_type, tenant) when mechanism_type in @deployment_mechanism_types do
    release = get_release_for_target(target, mechanism_type, tenant)

    {:ok, updated_target} =
      Campaigns.link_deployment(target, release, tenant: tenant, load: :deployment)

    # Send the deployment request
    updated_target
    |> Map.get(:deployment)
    |> Ash.Changeset.for_update(:send_deployment, %{deployment: updated_target.deployment}, tenant: tenant)
    |> Ash.update()

    updated_target
  end

  defp start_target_operation(target, :firmware_upgrade, tenant) do
    base_image =
      target.campaign_id
      |> Campaigns.fetch_campaign!(tenant: tenant)
      |> Ash.load!(campaign_mechanism: [firmware_upgrade: [:base_image]])
      |> Map.get(:campaign_mechanism)
      |> Map.get(:value)
      |> Map.get(:base_image)

    {:ok, target} = Campaigns.start_fw_upgrade(target, base_image)
    target
  end

  defp get_release_for_target(target, mechanism_type, tenant) do
    campaign = target |> Ash.load!(:campaign, tenant: tenant) |> Map.get(:campaign)
    # campaign = MechanismCore.get_campaign!(tenant.tenant_id, target.campaign_id)

    campaign_mechanism =
      campaign
      |> Ash.load!(
        campaign_mechanism: [
          {mechanism_type, [release: [containers: [:networks, :volumes, :image]]]}
        ]
      )
      |> Map.get(:campaign_mechanism)

    campaign_mechanism.value.release
  end

  # Target Termination Helpers

  defp terminated_target_fixture(opts, status) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {mechanism_type, opts} = Keyword.pop(opts, :mechanism_type, :deployment_deploy)
    {now, opts} = Keyword.pop(opts, :now, DateTime.utc_now())

    target =
      opts
      |> Keyword.merge(tenant: tenant, mechanism_type: mechanism_type, now: now)
      |> in_progress_target_fixture()

    # Update operation status based on mechanism type
    update_operation_status(target, mechanism_type, status, tenant)

    # Reload target with updated operation
    target = reload_target_with_operation(target, mechanism_type)

    case status do
      :failure -> MechanismCore.mark_target_as_failed!(Any, target, now)
      :success -> MechanismCore.mark_target_as_successful!(Any, target, now)
    end
  end

  defp update_operation_status(target, mechanism_type, status, tenant)
       when mechanism_type in @deployment_mechanism_types do
    # For deployment campaigns, update the deployment state
    deployment_status =
      case status do
        :success -> :running
        :failure -> :error
      end

    target.deployment_id
    |> Edgehog.Containers.fetch_deployment!(tenant: tenant)
    |> Ash.Changeset.for_update(:update_state, %{state: deployment_status}, tenant: tenant)
    |> Ash.update!()
  end

  defp update_operation_status(target, :firmware_upgrade, status, tenant) do
    target.ota_operation_id
    |> OSManagement.fetch_ota_operation!(tenant: tenant)
    |> OSManagement.update_ota_operation_status(status)
  end

  defp reload_target_with_operation(target, mechanism_type) when mechanism_type in @deployment_mechanism_types do
    Ash.load!(target, deployment: :state)
  end

  defp reload_target_with_operation(target, :firmware_upgrade) do
    Ash.load!(target, ota_operation: :status)
  end
end
