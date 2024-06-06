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
