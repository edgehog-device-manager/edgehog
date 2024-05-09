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

defmodule Edgehog.UpdateCampaigns.UpdateTarget do
  use Edgehog.MultitenantResource,
    domain: Edgehog.UpdateCampaigns,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.UpdateCampaigns.UpdateTarget

  resource do
    description """
    Represents an UpdateTarget.

    An Update Target is the target of an Update Campaign, which is composed \
    by the targeted device and the status of the target in the linked Update \
    Campaign.
    """
  end

  graphql do
    type :update_target
  end

  actions do
    defaults [:read]

    create :create do
      description "Creates a new update target."
      primary? true

      accept [:status, :update_campaign_id, :device_id]
    end

    update :update do
      description "Updates an update target."
      primary? true

      accept [:status, :retry_count, :latest_attempt, :completion_timestamp, :ota_operation_id]
    end
  end

  attributes do
    integer_primary_key :id

    attribute :status, UpdateTarget.Status do
      description "The status of the update target."
      public? true
      allow_nil? false
    end

    attribute :retry_count, :integer do
      description """
      The retry count of the update target. This indicates how many times \
      Edgehog has tried to send an OTA update towards the device without \
      receiving an ack.\
      """

      public? true
      allow_nil? false
      constraints min: 0
      default 0
    end

    attribute :latest_attempt, :utc_datetime_usec do
      description """
      The timestamp of the latest attempt to update the update target.\
      """

      public? true
    end

    attribute :completion_timestamp, :utc_datetime_usec do
      description """
      The timestamp when the update target completed its update, either with \
      a success or a failure.\
      """

      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :update_campaign, Edgehog.UpdateCampaigns.UpdateCampaign do
      description "The update campaign that is targeting the update target."
      public? true
      attribute_public? false
      allow_nil? false
    end

    belongs_to :device, Edgehog.Devices.Device do
      description "The target device."
      public? true
      attribute_public? false
      allow_nil? false
    end

    belongs_to :ota_operation, Edgehog.OSManagement.OTAOperation do
      description """
      The OTA operation that tracks the update target in-progress update.\
      """

      public? true
      attribute_public? false
      attribute_type :uuid
    end
  end

  postgres do
    table "update_campaign_targets"
    repo Edgehog.Repo

    references do
      reference :update_campaign,
        on_delete: :delete,
        match_type: :full,
        match_with: [tenant_id: :tenant_id]

      reference :device,
        on_delete: :nothing,
        match_type: :full,
        match_with: [tenant_id: :tenant_id]

      reference :ota_operation,
        on_delete: :nothing,
        match_with: [tenant_id: :tenant_id]
    end
  end
end
