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

defmodule Edgehog.DeploymentCampaignsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.DeploymentCampaigns` context.
  """

  alias Edgehog.CampaignsFixtures
  alias Edgehog.ContainersFixtures
  alias Edgehog.DeploymentCampaigns
  alias Edgehog.DevicesFixtures
  alias Edgehog.GroupsFixtures

  require Ash.Query

  @doc """
  Generate a unique deployment_campaign name.
  """
  def unique_deployment_campaign_name, do: "some name#{System.unique_integer([:positive])}"

  def deployment_campaign_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {deployment_channel_id, opts} =
      Keyword.pop_lazy(opts, :channel_id, fn ->
        [tenant: tenant] |> CampaignsFixtures.channel_fixture() |> Map.fetch!(:id)
      end)

    {release_id, opts} =
      Keyword.pop_lazy(opts, :release_id, fn ->
        [tenant: tenant] |> ContainersFixtures.release_fixture() |> Map.fetch!(:id)
      end)

    {deployment_mechanism_opts, opts} =
      Keyword.pop(opts, :deployment_mechanism, [])

    deployment_mechanism_opts =
      Enum.into(deployment_mechanism_opts, %{
        type: "lazy",
        max_failure_percentage: 50.0,
        max_in_progress_deployments: 100
      })

    params =
      Enum.into(opts, %{
        name: unique_deployment_campaign_name(),
        release_id: release_id,
        channel_id: deployment_channel_id,
        deployment_mechanism: deployment_mechanism_opts
      })

    Edgehog.DeploymentCampaigns.DeploymentCampaign
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generates an idle update target
  """
  def target_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {release_id, opts} =
      Keyword.pop_lazy(opts, :release_id, fn ->
        [tenant: tenant, system_models: 1]
        |> ContainersFixtures.release_fixture()
        |> Map.fetch!(:id)
      end)

    {tag, opts} = Keyword.pop(opts, :tag, "foo")

    {group_id, opts} =
      Keyword.pop_lazy(opts, :device_group_id, fn ->
        [selector: ~s<"#{tag}" in tags>, tenant: tenant]
        |> GroupsFixtures.device_group_fixture()
        |> Map.fetch!(:id)
      end)

    {channel_id, opts} =
      Keyword.pop_lazy(opts, :channel_id, fn ->
        [target_group_ids: [group_id], tenant: tenant]
        |> CampaignsFixtures.channel_fixture()
        |> Map.fetch!(:id)
      end)

    _ =
      opts
      |> Keyword.merge(release_id: release_id, online: true, tenant: tenant)
      |> DevicesFixtures.device_fixture_compatible_with_release()
      |> DevicesFixtures.add_tags([tag])

    deployment_campaign =
      deployment_campaign_fixture(
        release_id: release_id,
        channel_id: channel_id,
        tenant: tenant
      )

    deployment_campaign_id = deployment_campaign.id

    target =
      Edgehog.DeploymentCampaigns.DeploymentTarget
      |> Ash.Query.filter(deployment_campaign_id == ^deployment_campaign_id)
      |> Ash.read_one!(tenant: tenant, not_found_error?: true)

    target
  end

  @doc """
  Generates an update target with an associated OTA Operation
  """
  def in_progress_target_fixture(opts \\ []) do
    alias Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Core

    tenant = Keyword.fetch!(opts, :tenant)
    {now, opts} = Keyword.pop(opts, :now, DateTime.utc_now())

    # A little dance to create a target_fixture which has an associated OTA Operation
    target =
      opts
      |> target_fixture()
      |> Ash.load!(
        deployment: [:state],
        device: [realm: [:cluster]]
      )

    release =
      opts[:tenant]
      |> Core.get_deployment_campaign!(target.deployment_campaign_id)
      |> Ash.load!(
        [release: [containers: [:networks, :volumes, :image]]],
        tenant: tenant
      )
      |> Map.fetch!(:release)

    Mox.stub(
      Edgehog.Astarte.Device.CreateDeploymentRequestMock,
      :send_create_deployment_request,
      fn _client, _device_id, _data -> :ok end
    )

    {:ok, target} =
      target
      |> Core.update_target_latest_attempt!(now)
      |> DeploymentCampaigns.deploy_to_target(release, tenant: tenant)

    target
  end

  @doc """
  Generates an deployment campaign with N targets
  """
  def deployment_campaign_with_targets_fixture(target_count, opts \\ [])
      when is_integer(target_count) and target_count > 0 do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {release_id, opts} =
      Keyword.pop_lazy(opts, :release_id, fn ->
        [tenant: tenant, system_models: 1]
        |> ContainersFixtures.release_fixture()
        |> Map.fetch!(:id)
      end)

    tag = "foo"
    group = GroupsFixtures.device_group_fixture(selector: ~s<"#{tag}" in tags>, tenant: tenant)

    deployment_channel =
      CampaignsFixtures.channel_fixture(target_group_ids: [group.id], tenant: tenant)

    for _ <- 1..target_count do
      # Create devices as online by default
      _ =
        [release_id: release_id, online: true, tenant: tenant]
        |> DevicesFixtures.device_fixture_compatible_with_release()
        |> DevicesFixtures.add_tags([tag])
    end

    opts
    |> Keyword.merge(
      release_id: release_id,
      channel_id: deployment_channel.id,
      tenant: tenant
    )
    |> deployment_campaign_fixture()
  end
end
