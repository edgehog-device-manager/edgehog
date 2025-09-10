#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaignsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.UpdateCampaigns` context.
  """

  alias Edgehog.AstarteFixtures
  alias Edgehog.BaseImagesFixtures
  alias Edgehog.CampaignsFixtures
  alias Edgehog.DevicesFixtures
  alias Edgehog.GroupsFixtures

  require Ash.Query

  @doc """
  Generate a unique update_campaign name.
  """
  def unique_update_campaign_name, do: "some name#{System.unique_integer([:positive])}"

  def update_campaign_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {channel_id, opts} =
      Keyword.pop_lazy(opts, :channel_id, fn ->
        [tenant: tenant] |> CampaignsFixtures.channel_fixture() |> Map.fetch!(:id)
      end)

    {base_image_id, opts} =
      Keyword.pop_lazy(opts, :base_image_id, fn ->
        [tenant: tenant] |> BaseImagesFixtures.base_image_fixture() |> Map.fetch!(:id)
      end)

    {rollout_mechanism_opts, opts} = Keyword.pop(opts, :rollout_mechanism, [])

    rollout_mechanism_opts =
      Enum.into(rollout_mechanism_opts, %{
        type: "push",
        max_failure_percentage: 50.0,
        max_in_progress_updates: 100
      })

    params =
      Enum.into(opts, %{
        name: unique_update_campaign_name(),
        rollout_mechanism: rollout_mechanism_opts,
        base_image_id: base_image_id,
        channel_id: channel_id
      })

    Edgehog.UpdateCampaigns.UpdateCampaign
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generates an update campaign with N targets
  """
  def update_campaign_with_targets_fixture(target_count, opts \\ []) when is_integer(target_count) and target_count > 0 do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {base_image_id, opts} =
      Keyword.pop_lazy(opts, :base_image_id, fn ->
        [tenant: tenant] |> BaseImagesFixtures.base_image_fixture() |> Map.fetch!(:id)
      end)

    tag = "foo"
    group = GroupsFixtures.device_group_fixture(selector: ~s<"#{tag}" in tags>, tenant: tenant)

    channel = CampaignsFixtures.channel_fixture(target_group_ids: [group.id], tenant: tenant)

    for _ <- 1..target_count do
      # Create devices as online by default
      _ =
        [base_image_id: base_image_id, online: true, tenant: tenant]
        |> DevicesFixtures.device_fixture_compatible_with_base_image()
        |> DevicesFixtures.add_tags([tag])
    end

    opts
    |> Keyword.merge(
      base_image_id: base_image_id,
      channel_id: channel.id,
      tenant: tenant
    )
    |> update_campaign_fixture()
  end

  @doc """
  Generates an idle update target
  """
  def target_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {base_image_id, opts} =
      Keyword.pop_lazy(opts, :base_image_id, fn ->
        [tenant: tenant] |> BaseImagesFixtures.base_image_fixture() |> Map.fetch!(:id)
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
      |> Keyword.merge(base_image_id: base_image_id, online: true, tenant: tenant)
      |> DevicesFixtures.device_fixture_compatible_with_base_image()
      |> DevicesFixtures.add_tags([tag])

    update_campaign =
      update_campaign_fixture(
        base_image_id: base_image_id,
        channel_id: channel_id,
        tenant: tenant
      )

    update_campaign_id = update_campaign.id

    target =
      Edgehog.UpdateCampaigns.UpdateTarget
      |> Ash.Query.filter(update_campaign_id == ^update_campaign_id)
      |> Ash.read_one!(tenant: tenant, not_found_error?: true)

    target
  end

  @doc """
  Generates an update target with an associated OTA Operation
  """
  def in_progress_target_fixture(opts \\ []) do
    alias Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout.Core

    {now, opts} = Keyword.pop(opts, :now, DateTime.utc_now())

    # Expect Astarte Base Image for loading [device: :base_image] on target
    Mox.stub(Edgehog.Astarte.Device.BaseImageMock, :get, fn _client, _device_id ->
      {:ok, AstarteFixtures.base_image_info_fixture()}
    end)

    # A little dance to create a target_fixture which has an associated OTA Operation
    target =
      opts
      |> target_fixture()
      |> Ash.load!(Core.default_preloads_for_target())

    base_image = Core.get_update_campaign_base_image!(opts[:tenant], target.update_campaign_id)

    # Expect Astarte Device Status and OTA Request
    Mox.stub(Edgehog.Astarte.Device.DeviceStatusMock, :get, fn _client, _device_id ->
      {:ok, AstarteFixtures.device_status_fixture()}
    end)

    Mox.stub(
      Edgehog.Astarte.Device.OTARequestV1Mock,
      :update,
      fn _client, _device_id, _uuid, _url -> :ok end
    )

    {:ok, target} =
      target
      |> Core.update_target_latest_attempt!(now)
      |> Core.start_target_update(base_image)

    target
  end

  @doc """
  Generates a terminated update target with a success status
  This also sets the correct termination status to the associated OTA Operation.
  """
  def successful_target_fixture(opts \\ []) do
    terminated_target_fixture(opts, :success)
  end

  @doc """
  Generates a terminated update target with a failure status.
  This also sets the correct termination status to the associated OTA Operation.
  """
  def failed_target_fixture(opts \\ []) do
    terminated_target_fixture(opts, :failure)
  end

  defp terminated_target_fixture(opts, status) do
    alias Edgehog.OSManagement
    alias Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout.Core

    now = Keyword.get(opts, :now, DateTime.utc_now())

    target = in_progress_target_fixture(opts)

    {:ok, _} =
      target.ota_operation_id
      |> OSManagement.fetch_ota_operation!(tenant: opts[:tenant])
      |> OSManagement.update_ota_operation_status(status)

    # Get the updated OTA Operation preloaded
    target = Ash.load!(target, ota_operation: :status)

    case status do
      :failure ->
        Core.mark_target_as_failed!(target, now)

      :success ->
        Core.mark_target_as_successful!(target, now)
    end
  end
end
