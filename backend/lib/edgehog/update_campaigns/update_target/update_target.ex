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
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.UpdateCampaigns,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.UpdateCampaigns.UpdateTarget
  alias Edgehog.UpdateCampaigns.UpdateTarget.Changes

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

    read :read_next_updatable_target do
      description """
      Returns the next updatable target when updatable targets are present.
      The next updatable target is chosen with these criteria:
      - It must be idle.
      - It must be online.
      - It must either not have been attempted before or it has to be the least
      recently attempted target, in this order of preference.

      This set of constraints guarantees that when we make an attempt on a
      target that fails with a temporary error, given we update latest_attempt,
      we can read the next updatable target to attempt updates on other
      targets, or retry the same target if it is the only updatable one.
      """

      get? true
      argument :update_campaign_id, :integer, allow_nil?: false

      prepare build(load: [device: :online])
      prepare build(sort: [latest_attempt: :asc_nils_first])
      prepare build(limit: 1)

      filter expr(update_campaign_id == ^arg(:update_campaign_id))
      filter expr(status == :idle)
      filter expr(device.online == true)
    end

    read :read_targets_with_pending_ota_operation do
      description """
      Reads all the targets of an update campaign that have a pending OTA
      operation. This is useful when resuming an update campaign to know which
      targets need to setup a retry timeout.
      """

      argument :update_campaign_id, :integer, allow_nil?: false

      prepare build(load: [ota_operation: :status])

      filter expr(update_campaign_id == ^arg(:update_campaign_id))
      filter expr(not is_nil(ota_operation) and ota_operation.status == :pending)
    end

    create :create do
      description "Creates a new update target."
      primary? true

      accept [:status, :update_campaign_id, :device_id]
    end

    update :mark_as_in_progress do
      change set_attribute(:status, :in_progress)
    end

    update :mark_as_failed do
      argument :completion_timestamp, :utc_datetime_usec do
        default &DateTime.utc_now/0
      end

      change set_attribute(:completion_timestamp, arg(:completion_timestamp))
      change set_attribute(:status, :failed)
    end

    update :mark_as_successful do
      argument :completion_timestamp, :utc_datetime_usec do
        default &DateTime.utc_now/0
      end

      change set_attribute(:completion_timestamp, arg(:completion_timestamp))
      change set_attribute(:status, :successful)
    end

    update :increase_retry_count do
      change atomic_update(:retry_count, expr(retry_count + 1))
    end

    update :update_latest_attempt do
      accept [:latest_attempt]
    end

    update :start_update do
      description """
      Starts the OTA update for a target.
      It creates an OTA Operation, associates it with the update target, and
      sends the update request to the device.
      The update target is transitioned to the :in_progress status.
      """

      argument :base_image, :struct do
        constraints instance_of: BaseImage
        allow_nil? false
      end

      # Needed because CreateManagedOTAOperation is not atomic
      require_atomic? false

      change set_attribute(:status, :in_progress)
      change Changes.CreateManagedOTAOperation
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

  identities do
    identity :unique_device_for_campaign, [:update_campaign_id, :device_id]
  end

  postgres do
    table "update_campaign_targets"
    repo Edgehog.Repo

    references do
      reference :update_campaign,
        index?: true,
        on_delete: :delete,
        match_type: :full,
        match_with: [tenant_id: :tenant_id]

      reference :device,
        index?: true,
        on_delete: :nothing,
        match_type: :full,
        match_with: [tenant_id: :tenant_id]

      reference :ota_operation,
        on_delete: :nothing,
        match_with: [tenant_id: :tenant_id]
    end
  end
end
