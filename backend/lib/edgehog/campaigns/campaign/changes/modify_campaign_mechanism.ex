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

defmodule Edgehog.Campaigns.Campaign.Changes.ModifyCampaignMechanism do
  @moduledoc false

  use Ash.Resource.Change

  alias Ash.Changeset

  @common_keys [
    :max_failure_percentage,
    :max_in_progress_operations,
    :request_retries,
    :request_timeout_seconds
  ]

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    mechanism_type = changeset.data.campaign_mechanism.type

    if keys = keys_for_type(mechanism_type) do
      update_mechanism(changeset, keys)
    else
      changeset
    end
  end

  defp keys_for_type(:deployment_upgrade), do: [:release_id, :target_release_id] ++ @common_keys
  defp keys_for_type(:firmware_upgrade), do: [:base_image_id, :force_downgrade] ++ @common_keys

  defp keys_for_type(:file_download) do
    [
      :file_id,
      :ttl_seconds,
      :file_mode,
      :user_id,
      :group_id,
      :destination_type,
      :destination
    ] ++ @common_keys
  end

  defp keys_for_type(type)
       when type in [
              :deployment_deploy,
              :deployment_start,
              :deployment_stop,
              :deployment_delete
            ] do
    [:release_id] ++ @common_keys
  end

  defp keys_for_type(_unknown_type), do: nil

  defp update_mechanism(changeset, keys) do
    mechanism = changeset.data.campaign_mechanism
    mechanism_value = mechanism.value

    update_map =
      Map.new(keys, fn key ->
        val = Changeset.get_argument(changeset, key) || Map.get(mechanism_value, key)
        {key, val}
      end)

    updated_mechanism = %{mechanism | value: update_map}

    Changeset.change_attribute(changeset, :campaign_mechanism, updated_mechanism)
  end
end
