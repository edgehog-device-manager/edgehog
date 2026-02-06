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

defmodule Edgehog.Campaigns do
  @moduledoc """
  The Campaigns context.
  """

  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.CampaignTarget
  alias Edgehog.Campaigns.Channel

  graphql do
    root_level_errors? true

    queries do
      get Campaign, :campaign, :read do
        description "Returns the desired campaign."
      end

      list Campaign, :update_campaigns, :update_campaign do
        description "Returns all update campaigns."
        paginate_with :keyset
        relay? true
      end

      list Campaign, :deployment_campaigns, :deployment_campaign do
        description "Returns all deployment campaigns."
        paginate_with :keyset
        relay? true
      end

      list Campaign, :campaigns, :read do
        description "Returns all available campaigns."
        paginate_with :keyset
        relay? true
      end

      get Channel, :channel, :read do
        description "Returns a single channel."
      end

      list Channel, :channels, :read do
        description "Returns a list of channels."
        paginate_with :keyset
        relay? true
      end
    end

    mutations do
      create Campaign, :create_campaign, :create do
        relay_id_translations input: [
                                channel_id: :channel,
                                campaign_mechanism: [
                                  deployment_deploy: [release_id: :release],
                                  deployment_start: [release_id: :release],
                                  deployment_stop: [release_id: :release],
                                  deployment_delete: [release_id: :release],
                                  deployment_upgrade: [
                                    release_id: :release,
                                    target_release_id: :release
                                  ],
                                  firmware_upgrade: [base_image_id: :base_image]
                                ]
                              ]
      end

      update Campaign, :pause_campaign, :pause do
        description "Pauses an in-progress campaign rollout."
      end

      update Campaign, :resume_campaign, :resume do
        description "Resumes a paused campaign rollout."
      end

      create Channel, :create_channel, :create do
        relay_id_translations input: [target_group_ids: :device_group]
      end

      update Channel, :update_channel, :update do
        relay_id_translations input: [target_group_ids: :device_group]
      end

      destroy Channel, :delete_channel, :destroy
    end
  end

  resources do
    resource Campaign do
      define :fetch_campaign, action: :read, get_by: [:id]
      define :mark_campaign_in_progress, action: :mark_as_in_progress
      define :mark_campaign_paused, action: :mark_as_paused
      define :mark_campaign_failed, action: :mark_as_failed
      define :mark_campaign_successful, action: :mark_as_successful
      define :pause_campaign, action: :pause
      define :resume_campaign, action: :resume
    end

    resource CampaignTarget do
      define :fetch_next_valid_target,
        action: :next_valid_target,
        args: [:campaign_id],
        get?: true,
        not_found_error?: true

      define :fetch_target, action: :read, get_by: [:id], not_found_error?: true

      define :list_in_progress_targets,
        action: :read_in_progress_targets,
        args: [:campaign_id]

      define :list_targets_with_pending_ota_operation,
        action: :read_targets_with_pending_ota_operation,
        args: [:campaign_id]

      define :fetch_next_valid_target_with_application_deployed,
        action: :next_valid_target_with_application_deployed,
        args: [:campaign_id, :application_id]

      define :fetch_target_by_deployment,
        action: :read,
        get_by: [:deployment_id],
        not_found_error?: true

      define :fetch_target_by_device_and_campaign,
        action: :read,
        get_by: [:device_id, :campaign_id],
        not_found_error?: true

      define :mark_target_as_in_progress, action: :mark_as_in_progress
      define :mark_target_as_failed, action: :mark_as_failed
      define :mark_target_as_successful, action: :mark_as_successful

      define :increase_target_retry_count, action: :increase_retry_count

      define :update_target_latest_attempt,
        action: :update_latest_attempt,
        args: [:latest_attempt]

      define :link_deployment, action: :link_deployment, args: [:release]
      define :start_fw_upgrade, action: :start_fw_upgrade, args: [:base_image]

      define :set_target_deployment, action: :set_deployment, args: [:deployment_id]
    end

    resource Channel
  end
end
