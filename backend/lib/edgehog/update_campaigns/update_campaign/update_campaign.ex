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
