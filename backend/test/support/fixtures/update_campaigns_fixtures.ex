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

  alias Edgehog.BaseImagesFixtures
  alias Edgehog.DevicesFixtures
  alias Edgehog.GroupsFixtures

  require Ash.Query

  @doc """
  Generate a unique update_channel handle.
  """
  def unique_update_channel_handle, do: "some-handle#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique update_channel name.
  """
  def unique_update_channel_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique update_campaign name.
  """
  def unique_update_campaign_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a update_channel.
  """
  def update_channel_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {target_group_ids, opts} =
      Keyword.pop_lazy(opts, :target_group_ids, fn ->
        target_group = Edgehog.GroupsFixtures.device_group_fixture(tenant: tenant)
        [target_group.id]
      end)

    params =
      Enum.into(opts, %{
        handle: unique_update_channel_handle(),
        name: unique_update_channel_name(),
        target_group_ids: target_group_ids
      })

    Edgehog.UpdateCampaigns.UpdateChannel
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  def update_campaign_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {update_channel_id, opts} =
      Keyword.pop_lazy(opts, :update_channel_id, fn ->
        update_channel_fixture(tenant: tenant) |> Map.fetch!(:id)
      end)

    {base_image_id, opts} =
      Keyword.pop_lazy(opts, :base_image_id, fn ->
        Edgehog.BaseImagesFixtures.base_image_fixture(tenant: tenant) |> Map.fetch!(:id)
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
        update_channel_id: update_channel_id
      })

    Edgehog.UpdateCampaigns.UpdateCampaign
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generates an update campaign with N targets
  """
  def update_campaign_with_targets_fixture(target_count, opts \\ [])
      when is_integer(target_count) and target_count > 0 do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {base_image_id, opts} =
      Keyword.pop_lazy(opts, :base_image_id, fn ->
        Edgehog.BaseImagesFixtures.base_image_fixture(tenant: tenant) |> Map.fetch!(:id)
      end)

    tag = "foo"
    group = GroupsFixtures.device_group_fixture(selector: ~s<"#{tag}" in tags>, tenant: tenant)

    update_channel = update_channel_fixture(target_group_ids: [group.id], tenant: tenant)

    for _ <- 1..target_count do
      # Create devices as online by default
      _ =
        DevicesFixtures.device_fixture_compatible_with(
          base_image_id: base_image_id,
          online: true,
          tenant: tenant
        )
        |> DevicesFixtures.add_tags([tag])
    end

    opts
    |> Keyword.merge(
      base_image_id: base_image_id,
      update_channel_id: update_channel.id,
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
        Edgehog.BaseImagesFixtures.base_image_fixture(tenant: tenant) |> Map.fetch!(:id)
      end)

    {tag, opts} = Keyword.pop(opts, :tag, "foo")

    {group_id, opts} =
      Keyword.pop_lazy(opts, :device_group_id, fn ->
        GroupsFixtures.device_group_fixture(selector: ~s<"#{tag}" in tags>, tenant: tenant)
        |> Map.fetch!(:id)
      end)

    {update_channel_id, opts} =
      Keyword.pop_lazy(opts, :update_channel_id, fn ->
        update_channel_fixture(target_group_ids: [group_id], tenant: tenant) |> Map.fetch!(:id)
      end)

    _ =
      opts
      |> Keyword.merge(base_image_id: base_image_id, online: true, tenant: tenant)
      |> DevicesFixtures.device_fixture_compatible_with()
      |> DevicesFixtures.add_tags([tag])

    update_campaign =
      update_campaign_fixture(
        base_image_id: base_image_id,
        update_channel_id: update_channel_id,
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

    # Stub Astarte Base Image for loading [device: :base_image] on target
    Mox.stub_with(
      Edgehog.Astarte.Device.BaseImageMock,
      Edgehog.Mocks.Astarte.Device.BaseImage
    )

    # A little dance to create a target_fixture which has an associated OTA Operation
    target =
      target_fixture(opts)
      |> Ash.load!(Core.default_preloads_for_target())

    base_image = Core.get_update_campaign_base_image!(opts[:tenant], target.update_campaign_id)

    # Stub Astarte Device Status and OTA Request
    Mox.stub_with(
      Edgehog.Astarte.Device.DeviceStatusMock,
      Edgehog.Mocks.Astarte.Device.DeviceStatus
    )

    Mox.stub_with(
      Edgehog.Astarte.Device.OTARequestV1Mock,
      Edgehog.Mocks.Astarte.Device.OTARequest.V1
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
    alias Edgehog.UpdateCampaigns

    now = Keyword.get(opts, :now, DateTime.utc_now())

    target = in_progress_target_fixture(opts)

    {:ok, _} =
      OSManagement.OTAOperation
      |> Ash.get!(target.ota_operation_id, tenant: opts[:tenant])
      |> Ash.Changeset.for_update(:update, %{status: status})
      |> Ash.update()

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
