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

defmodule Edgehog.DeploymentCampaigns do
  @moduledoc """
  Deployment Campaigns context.

  This module provides the necessary code interfaces and GraphQL mutations (and
  queries) to interact with deployment campaigns.
  """
  use Ash.Domain,
    extensions: [AshGraphql.Domain]

  alias Edgehog.DeploymentCampaigns.DeploymentCampaign

  graphql do
    root_level_errors? true

    queries do
      get DeploymentCampaign, :deployment_campaign, :read do
        description "Returns the desired deployment campaign."
      end

      list DeploymentCampaign, :deployment_campaigns, :read do
        description "Returns all available deployment campaigns."
        paginate_with :keyset
        relay? true
      end
    end

    mutations do
      create DeploymentCampaign, :create_deployment_campaign, :create do
        relay_id_translations input: [
                                release_id: :release,
                                target_release_id: :release,
                                channel_id: :channel
                              ]
      end
    end
  end

  resources do
    resource DeploymentCampaign do
      define :fetch_campaign, action: :read, get_by: [:id]
      define :mark_campaign_in_progress, action: :mark_as_in_progress
      define :mark_campaign_failed, action: :mark_as_failed
      define :mark_campaign_successful, action: :mark_as_successful
    end

    resource Edgehog.DeploymentCampaigns.DeploymentTarget do
      define :fetch_next_valid_target,
        action: :next_valid_target,
        args: [:deployment_campaign_id],
        get?: true,
        not_found_error?: true

      define :fetch_target, action: :read, get_by: [:id], not_found_error?: true

      define :list_in_progress_targets,
        action: :read_in_progress_targets,
        args: [:deployment_campaign_id]

      define :fetch_next_valid_target_with_application_deployed,
        action: :next_valid_target_with_application_deployed,
        args: [:deployment_campaign_id, :application_id]

      define :fetch_target_by_deployment,
        action: :read,
        get_by: [:deployment_id],
        not_found_error?: true

      define :fetch_target_by_device_and_campaign,
        action: :read,
        get_by: [:device_id, :deployment_campaign_id],
        not_found_error?: true

      define :mark_target_as_in_progress, action: :mark_as_in_progress
      define :mark_target_as_failed, action: :mark_as_failed
      define :mark_target_as_successful, action: :mark_as_successful

      define :increase_target_retry_count, action: :increase_retry_count

      define :update_target_latest_attempt,
        action: :update_latest_attempt,
        args: [:latest_attempt]

      define :deploy_to_target, action: :deploy, args: [:release]

      define :set_target_deployment, action: :set_deployment, args: [:deployment_id]
    end
  end
end
