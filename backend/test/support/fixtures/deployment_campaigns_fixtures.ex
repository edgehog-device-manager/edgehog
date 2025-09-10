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

  alias Edgehog.ContainersFixtures
  alias Edgehog.DevicesFixtures
  alias Edgehog.GroupsFixtures

  require Ash.Query

  @doc """
  Generate a unique deployment_channel handle.
  """
  def unique_deployment_channel_handle, do: "some-handle#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique deployment_channel name.
  """
  def unique_deployment_channel_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique deployment_campaign name.
  """
  def unique_deployment_campaign_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a deployment_channel.
  """
  def deployment_channel_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {target_group_ids, opts} =
      Keyword.pop_lazy(opts, :target_group_ids, fn ->
        target_group = Edgehog.GroupsFixtures.device_group_fixture(tenant: tenant)
        [target_group.id]
      end)

    params =
      Enum.into(opts, %{
        handle: unique_deployment_channel_handle(),
        name: unique_deployment_channel_name(),
        target_group_ids: target_group_ids
      })

    Edgehog.DeploymentCampaigns.DeploymentChannel
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  def deployment_campaign_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {deployment_channel_id, opts} =
      Keyword.pop_lazy(opts, :deployment_channel_id, fn ->
        [tenant: tenant] |> deployment_channel_fixture() |> Map.fetch!(:id)
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
        deployment_channel_id: deployment_channel_id,
        deployment_mechanism: deployment_mechanism_opts
      })

    Edgehog.DeploymentCampaigns.DeploymentCampaign
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
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

    deployment_channel = deployment_channel_fixture(target_group_ids: [group.id], tenant: tenant)

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
      deployment_channel_id: deployment_channel.id,
      tenant: tenant
    )
    |> deployment_campaign_fixture()
  end
end
