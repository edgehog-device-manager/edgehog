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

defmodule Edgehog.UpdateCampaigns.UpdateCampaign do
  use Edgehog.MultitenantResource,
    domain: Edgehog.UpdateCampaigns,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.UpdateCampaigns.UpdateCampaign
  alias Edgehog.UpdateCampaigns.UpdateCampaign.Changes

  resource do
    description """
    Represents an UpdateCampaign.

    An Update Campaign is the operation that tracks the distribution of a \
    specific Base Image to all devices belonging to an Update Channel.
    """
  end

  graphql do
    type :update_campaign
  end

  actions do
    defaults [:read]

    read :read_all_resumable do
      multitenancy :allow_global
      pagination keyset?: true
      filter expr(status in [:idle, :in_progress])
    end

    create :create do
      description "Creates a new update campaign."
      primary? true

      accept [:name, :rollout_mechanism]

      argument :base_image_id, :id do
        description """
        The ID of the base image that will be distributed in the update \
        campaign.\
        """

        allow_nil? false
      end

      argument :update_channel_id, :id do
        description """
        The ID of the update channel that will be targeted by the update \
        campaign.\
        """

        allow_nil? false
      end

      change Changes.ComputeUpdateTargets

      change manage_relationship(:base_image_id, :base_image, type: :append)
      change manage_relationship(:update_channel_id, :update_channel, type: :append)
    end

    update :update do
      description "Updates an update campaign."
      primary? true

      accept [:status, :outcome, :start_timestamp, :completion_timestamp]
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

    destroy :destroy do
      description "Deletes an update campaign."
      primary? true
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      description "The name of the update campaign."
      public? true
      allow_nil? false
    end

    attribute :status, UpdateCampaign.Status do
      description "The status of the update campaign."
      public? true
      allow_nil? false
    end

    attribute :outcome, UpdateCampaign.Outcome do
      description """
      The outcome of the update campaign, present only when it's finished.
      """

      public? true
    end

    attribute :rollout_mechanism, Edgehog.UpdateCampaigns.RolloutMechanism do
      description """
      The rollout mechanism used in the update campaign.
      """

      public? true
      allow_nil? false
    end

    attribute :start_timestamp, :utc_datetime_usec
    attribute :completion_timestamp, :utc_datetime_usec

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :base_image, Edgehog.BaseImages.BaseImage do
      description "The base image distributed by the update campaign."
      public? true
      attribute_public? false
      allow_nil? false
    end

    belongs_to :update_channel, Edgehog.UpdateCampaigns.UpdateChannel do
      description "The update channel targeted by the update campaign."
      public? true
      attribute_public? false
      allow_nil? false
    end

    has_many :update_targets, Edgehog.UpdateCampaigns.UpdateTarget do
      description "The update targets belonging to the update campaign."
      public? true
      writable? false
    end
  end

  aggregates do
    count :total_target_count, :update_targets do
      description "The total number of update targets."
      public? true
    end

    count :idle_target_count, :update_targets do
      description "The number of update targets with an idle status."
      public? true
      filter expr(status == :idle)
    end

    count :in_progress_target_count, :update_targets do
      description "The number of update targets with an in-progress status."
      public? true
      filter expr(status == :in_progress)
    end

    count :failed_target_count, :update_targets do
      description "The number of update targets with a failed status."
      public? true
      filter expr(status == :failed)
    end

    count :successful_target_count, :update_targets do
      description "The number of update targets with a successful status."
      public? true
      filter expr(status == :successful)
    end
  end

  postgres do
    table "update_campaigns"
    repo Edgehog.Repo

    references do
      reference :base_image,
        on_delete: :nothing,
        match_type: :full,
        match_with: [tenant_id: :tenant_id]

      reference :update_channel,
        on_delete: :nothing,
        match_type: :full,
        match_with: [tenant_id: :tenant_id]
    end
  end
end
