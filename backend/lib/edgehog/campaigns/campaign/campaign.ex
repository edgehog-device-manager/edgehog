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

defmodule Edgehog.Campaigns.Campaign do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Campaigns,
    extensions: [AshGraphql.Resource],
    notifiers: [Ash.Notifier.PubSub]

  alias Edgehog.Campaigns.Campaign.Changes
  alias Edgehog.Campaigns.Campaign.Validations
  alias Edgehog.Campaigns.CampaignMechanism
  alias Edgehog.Campaigns.CampaignTarget
  alias Edgehog.Campaigns.Channel
  alias Edgehog.Campaigns.Outcome
  alias Edgehog.Campaigns.Status

  graphql do
    type :campaign

    paginate_relationship_with campaign_targets: :relay

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :campaigns do
        action_types [:create, :update]
      end

      subscribe :deployment_campaigns do
        action_types [:create, :update]
        read_action :deployment_campaigns
      end

      subscribe :update_campaigns do
        action_types [:create, :update]
        read_action :update_campaigns
      end

      subscribe :campaign do
        action_types [:update]
        read_action :get_by_id
        relay_id_translations id: :campaign
      end
    end
  end

  actions do
    defaults [:read]

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false
      get? true

      filter expr(id == ^arg(:id))
    end

    read :read_all_resumable do
      multitenancy :allow_global
      pagination keyset?: true
      filter expr(status in [:idle, :in_progress, :pausing])
    end

    # TODO: allow filtering per base_image_id
    read :update_campaigns do
      argument :types, {:array, :atom}
      multitenancy :allow_global
      pagination keyset?: true
      filter expr(campaign_mechanism[:type] in [:firmware_upgrade])
    end

    read :deployment_campaigns do
      argument :types, {:array, :atom}
      multitenancy :allow_global
      pagination keyset?: true

      filter expr(
               campaign_mechanism[:type] in [
                 :deployment_deploy,
                 :deployment_start,
                 :deployment_stop,
                 :deployment_delete,
                 :deployment_upgrade
               ]
             )
    end

    create :create do
      description "Creates a new campaign."
      primary? true

      accept [:name, :campaign_mechanism]

      argument :channel_id, :id do
        description """
        The ID of the channel that will be targeted by the campaign.
        """

        allow_nil? false
      end

      validate Validations.RequireCampaignMechanism, only_when_valid?: true
      validate Validations.ValidateOperationTypeRequirements, only_when_valid?: true

      change Changes.ComputeCampaignTargets, only_when_valid?: true

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

    update :mark_as_paused do
      change set_attribute(:status, :paused)
    end

    update :pause do
      require_atomic? false

      validate {Validations.ValidateStatus, operation: :pause}
      change set_attribute(:status, :pausing)
    end

    update :resume do
      require_atomic? false

      validate {Validations.ValidateStatus, operation: :resume}
      change Changes.StartExecution
    end

    update :trigger_subscription do
      description """
      This is a nop action used only to trigger subscriptions.
      """
    end

    destroy :destroy do
      description "Deletes a Campaign"
      primary? true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :status, Status do
      description "The status of the campaign."
      public? true
      allow_nil? false
    end

    attribute :outcome, Outcome do
      description "The outcome of the campaign."
      public? true
    end

    attribute :campaign_mechanism, CampaignMechanism do
      description "The campaign mechanism to carry the campaign."

      public? true
      allow_nil? false
    end

    attribute :start_timestamp, :utc_datetime_usec
    attribute :completion_timestamp, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :channel, Channel do
      description "The channel associated with the campaign."
      public? true
      allow_nil? false
      attribute_public? false
      attribute_type :id
    end

    has_many :campaign_targets, CampaignTarget do
      description "The campaign targets belonging to the campaign."
      public? true
      writable? false
    end
  end

  aggregates do
    count :total_target_count, :campaign_targets do
      description "The total number of campaign targets."
      public? true
    end

    count :idle_target_count, :campaign_targets do
      description "The number of campaign targets with an idle status."
      public? true
      filter expr(status == :idle)
    end

    count :in_progress_target_count, :campaign_targets do
      description "The number of campaign targets with an in-progress status."
      public? true
      filter expr(status == :in_progress)
    end

    count :failed_target_count, :campaign_targets do
      description "The number of campaign targets with a failed status."
      public? true
      filter expr(status == :failed)
    end

    count :successful_target_count, :campaign_targets do
      description "The number of campaign targets with a successful status."
      public? true
      filter expr(status == :successful)
    end
  end

  pub_sub do
    prefix "campaigns"
    module EdgehogWeb.Endpoint

    publish :pause, [[:id, "*"]]
  end

  postgres do
    table "campaigns"

    references do
      reference :channel,
        index?: true,
        on_delete: :nothing,
        match_type: :full,
        match_with: [tenant_id: :tenant_id]
    end
  end
end
