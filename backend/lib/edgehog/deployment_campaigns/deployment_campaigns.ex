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
  Deployment Campaings context.

  This module provides the necessary code interfaces and GraphQL mutations (and
  queries) to interact with deployment campaigns.
  """
  use Ash.Domain,
    extensions: [AshGraphql.Domain]

  alias Edgehog.DeploymentCampaigns.DeploymentCampaign
  alias Edgehog.DeploymentCampaigns.DeploymentChannel

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

      get DeploymentChannel, :deployment_channel, :read do
        description "Returns the desired deployment channel."
      end

      list DeploymentChannel, :deployment_channels, :read do
        description "Returns all available deployment channels."
        paginate_with :keyset
        relay? true
      end
    end
  end

  resources do
    resource Edgehog.DeploymentCampaigns.DeploymentCampaign do
      define :get_campaign, action: :read, get_by: [:id]
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
    end

    resource Edgehog.DeploymentCampaigns.DeploymentChannel
  end
end
