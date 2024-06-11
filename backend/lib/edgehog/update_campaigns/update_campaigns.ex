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

defmodule Edgehog.UpdateCampaigns do
  @moduledoc """
  The UpdateCampaigns context.
  """

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  graphql do
    root_level_errors? true

    queries do
      get Edgehog.UpdateCampaigns.UpdateCampaign, :update_campaign, :read do
        description "Returns a single update campaign."
      end

      list Edgehog.UpdateCampaigns.UpdateCampaign, :update_campaigns, :read do
        description "Returns a list of update campaigns."
        paginate_with nil
      end

      get Edgehog.UpdateCampaigns.UpdateChannel, :update_channel, :read do
        description "Returns a single update channel."
      end

      list Edgehog.UpdateCampaigns.UpdateChannel, :update_channels, :read do
        description "Returns a list of update channels."
        paginate_with nil
      end
    end

    mutations do
      create Edgehog.UpdateCampaigns.UpdateCampaign, :create_update_campaign, :create do
        relay_id_translations input: [
                                base_image_id: :base_image,
                                update_channel_id: :update_channel
                              ]
      end

      create Edgehog.UpdateCampaigns.UpdateChannel, :create_update_channel, :create do
        relay_id_translations input: [target_group_ids: :device_group]
      end

      update Edgehog.UpdateCampaigns.UpdateChannel, :update_update_channel, :update do
        relay_id_translations input: [target_group_ids: :device_group]
      end

      destroy Edgehog.UpdateCampaigns.UpdateChannel, :delete_update_channel, :destroy
    end
  end

  resources do
    resource Edgehog.UpdateCampaigns.UpdateCampaign do
      define :fetch_campaign, action: :read, get_by: [:id], not_found_error?: true
      define :mark_campaign_as_in_progress, action: :mark_as_in_progress
      define :mark_campaign_as_failed, action: :mark_as_failed
      define :mark_campaign_as_successful, action: :mark_as_successful
    end

    resource Edgehog.UpdateCampaigns.UpdateChannel

    resource Edgehog.UpdateCampaigns.UpdateTarget do
      define :fetch_target, action: :read, get_by: [:id], not_found_error?: true

      define :fetch_next_updatable_target,
        action: :read_next_updatable_target,
        args: [:update_campaign_id],
        get?: true,
        not_found_error?: true

      define :fetch_target_by_ota_operation,
        action: :read,
        get_by: [:ota_operation_id],
        not_found_error?: true

      define :list_targets_with_pending_ota_operation,
        action: :read_targets_with_pending_ota_operation,
        args: [:update_campaign_id]

      define :mark_target_as_in_progress, action: :mark_as_in_progress
      define :mark_target_as_failed, action: :mark_as_failed
      define :mark_target_as_successful, action: :mark_as_successful
      define :increase_target_retry_count, action: :increase_retry_count

      define :update_target_latest_attempt,
        action: :update_latest_attempt,
        args: [:latest_attempt]

      define :start_target_update, action: :start_update, args: [:base_image]
    end
  end
end
