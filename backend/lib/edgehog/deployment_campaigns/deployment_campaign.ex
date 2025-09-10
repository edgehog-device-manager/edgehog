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

defmodule Edgehog.DeploymentCampaigns.DeploymentCampaign do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.DeploymentCampaigns,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Campaigns.Outcome
  alias Edgehog.Campaigns.Status
  alias Edgehog.Containers.Release
  alias Edgehog.DeploymentCampaigns.DeploymentCampaign.Changes

  graphql do
    type :deployment_campaign
    paginate_relationship_with deployment_targets: :relay
  end

  actions do
    defaults [:read]

    create :create do
      description "Creates a new deployment campaign."
      primary? true

      accept [:name, :deployment_mechanism]

      argument :release_id, :uuid do
        description """
        The ID of the release that will be distributed in the deployment campaign.
        """

        allow_nil? false
      end

      argument :channel_id, :id do
        description """
        The ID of the channel that will be targeted by the deployment campaign.
        """

        allow_nil? false
      end

      change Changes.ComputeDeploymentTargets
      change set_attribute(:status, :idle)

      change manage_relationship(:release_id, :release, type: :append)
      change manage_relationship(:channel_id, :channel, type: :append)
    end

    update :mark_as_in_progress do
      argument :start_timestamp, :utc_datetime_usec do
        default &DateTime.utc_now/0
      end

      change set_attribute(:start_timestamp, arg(:start_timestamp))
      change set_attribute(:status, :in_progress)
    end

    update :mark_as_failed do
      argument :completion_timestamp, :utc_datetime_usec do
        default &DateTime.utc_now/0
      end

      change set_attribute(:completion_timestamp, arg(:completion_timestamp))
      change set_attribute(:status, :finished)
      change set_attribute(:outcome, :failure)
    end

    update :mark_as_successful do
      argument :completion_timestamp, :utc_datetime_usec do
        default &DateTime.utc_now/0
      end

      change set_attribute(:completion_timestamp, arg(:completion_timestamp))
      change set_attribute(:status, :finished)
      change set_attribute(:outcome, :success)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :status, Status do
      description "The status of the deployment campaign."
      public? true
      allow_nil? false
    end

    attribute :outcome, Outcome do
      description "The outcome of the deployment campaign."
      public? true
    end

    attribute :deployment_mechanism, Edgehog.DeploymentCampaigns.DeploymentMechanism do
      description """
      The deployment mechanism to carry the campaign.
      """

      public? true
      allow_nil? false
    end

    attribute :start_timestamp, :utc_datetime_usec
    attribute :completion_timestamp, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :release, Release do
      description "The release distributed by the deployment campaign."
      public? true
      attribute_public? false
      attribute_type :uuid
      allow_nil? false
    end

    belongs_to :channel, Edgehog.Campaigns.Channel do
      description "The channel associated with the campaign."
      public? true
      allow_nil? false
      attribute_public? false
      attribute_type :id
    end

    has_many :deployment_targets, Edgehog.DeploymentCampaigns.DeploymentTarget do
      description "The depployment targets belonging to the deployment campaign."
      public? true
      writable? false
    end
  end

  aggregates do
    count :total_target_count, :deployment_targets do
      description "The total number of deployment targets."
      public? true
    end

    count :idle_target_count, :deployment_targets do
      description "The number of deployment targets with an idle status."
      public? true
      filter expr(status == :idle)
    end

    count :in_progress_target_count, :deployment_targets do
      description "The number of deployment targets with an in-progress status."
      public? true
      filter expr(status == :in_progress)
    end

    count :failed_target_count, :deployment_targets do
      description "The number of deployment targets with a failed status."
      public? true
      filter expr(status == :failed)
    end

    count :successful_target_count, :deployment_targets do
      description "The number of deployment targets with a successful status."
      public? true
      filter expr(status == :successful)
    end
  end

  postgres do
    table "deployment_campaign"

    references do
      reference :channel,
        index?: true,
        on_delete: :nothing,
        match_type: :full,
        match_with: [tenant_id: :tenant_id]
    end
  end
end
