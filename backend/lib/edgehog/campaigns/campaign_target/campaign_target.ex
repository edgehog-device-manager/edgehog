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

defmodule Edgehog.Campaigns.CampaignTarget do
  @moduledoc """
  Represents a CampaignTarget.

  Campaign targets are the targets of a Campaign, which is composed
  by the target device and the state of the target in the linked
  Campaign
  """

  use Edgehog.MultitenantResource,
    domain: Edgehog.Campaigns,
    extensions: [AshGraphql.Resource]

  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.Campaigns.CampaignTarget
  alias Edgehog.Campaigns.CampaignTarget.Changes
  alias Edgehog.Containers.Release

  resource do
    description @moduledoc
  end

  graphql do
    type :campaign_target
  end

  actions do
    defaults [:read]

    read :next_valid_target do
      description """
      Returns the next valid target.
      The next valid target is chosen with these criteria:
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
      argument :campaign_id, :uuid, allow_nil?: false

      prepare build(load: [device: :online])
      prepare build(sort: [latest_attempt: :asc_nils_first])
      prepare build(limit: 1)

      filter expr(campaign_id == ^arg(:campaign_id))
      filter expr(status == :idle)
      filter expr(device.online == true)
    end

    read :read_in_progress_targets do
      description """
      Reads all the targets of a campaign that have `in_progress`
      status. This is useful when resuming an campaign to know which
      targets need to setup a retry timeout.
      """

      argument :campaign_id, :uuid, allow_nil?: false

      filter expr(campaign_id == ^arg(:campaign_id))
      filter expr(status == :in_progress)
    end

    read :read_targets_with_pending_ota_operation do
      description """
      Reads all the targets of an update campaign that have a pending OTA
      operation. This is useful when resuming an update campaign to know which
      targets need to setup a retry timeout.
      """

      argument :campaign_id, :uuid, allow_nil?: false

      prepare build(load: [ota_operation: :status])

      filter expr(campaign_id == ^arg(:campaign_id))
      filter expr(not is_nil(ota_operation) and ota_operation.status == :pending)
    end

    read :next_valid_target_with_application_deployed do
      description """
      Returns the next valid target whose device has a specific application deployed.

      The next valid target is chosen with these criteria:
      - Must be idle
      - Must be online
      - Must have the specified application deployed
      - It must either not have been attempted before or it has to be the least
      recently attempted target, in this order of preference.

      This set of constraints guarantees that when we make an attempt on a
      target that fails with a temporary error, given we update latest_attempt,
      we can read the next deployable target to attempt deployment operations on other
      targets, or retry the same target if it is the only deployable one.
      This is useful for campaigns that require an existing deployment to be present
      (e.g., start, stop, upgrade, delete operations).
      """

      get? true
      argument :campaign_id, :uuid, allow_nil?: false
      argument :application_id, :uuid, allow_nil?: false

      prepare build(load: [device: [:online, application_deployments: :release]])
      prepare build(sort: [latest_attempt: :asc_nils_first])
      prepare build(limit: 1)

      filter expr(campaign_id == ^arg(:campaign_id))
      filter expr(status == :idle)
      filter expr(device.online == true)

      filter expr(
               exists(
                 device.application_deployments,
                 release.application_id == ^arg(:application_id)
               )
             )
    end

    create :create do
      description "Creates a new campaign target."
      primary? true

      accept [:status, :campaign_id, :device_id]
    end

    # Generic updates

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

    # Deployment related updates

    update :link_deployment do
      description """
      Start a deployment towards this target.
      It creates a Deployment and associates it with the target, sending all the
      necessary requests to the device.
      The target is marked as :in_progress.
      """

      argument :release, :struct do
        constraints instance_of: Release
        allow_nil? false
      end

      require_atomic? false

      change set_attribute(:status, :in_progress)
      change Changes.LinkDeployment
    end

    update :set_deployment do
      description """
      Links an existing deployment to this target.
      The target is marked as :in_progress.
      """

      accept [:deployment_id]

      require_atomic? false

      change set_attribute(:status, :in_progress)
    end

    # Firmware upgrade related updates

    update :start_fw_upgrade do
      description """
      Starts the OTA update for a target.
      It creates an OTA Operation, associates it with the campaign target, and
      sends the update request to the device.
      The campaign target is transitioned to the :in_progress status.
      """

      argument :base_image, :struct do
        constraints instance_of: BaseImage
        allow_nil? false
      end

      require_atomic? false

      change set_attribute(:status, :in_progress)
      change Changes.CreateManagedOTAOperation
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, CampaignTarget.Status do
      description "The status of the campaign target."
      public? true
      allow_nil? false
    end

    attribute :retry_count, :integer do
      description """
      The number of retries of the campaign target. This indicated how many times
      Edgehog retried to send all the necessary information about an operation towards
      the device without receiving acks.
      """

      public? true
      allow_nil? false
      constraints min: 0
      default 0
    end

    attribute :latest_attempt, :utc_datetime_usec do
      description """
      The timestamp of the latest attempt to deploy to the campaign target.
      """

      public? true
    end

    attribute :completion_timestamp, :utc_datetime_usec do
      description """
      The timestamp when the campaign target completed its update, either with
      a success or a failure.
      """

      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :campaign, Edgehog.Campaigns.Campaign do
      public? true
      allow_nil? false
      attribute_public? false
      attribute_type :uuid
    end

    belongs_to :device, Edgehog.Devices.Device do
      public? true
      allow_nil? false
      attribute_public? false
    end

    belongs_to :deployment, Edgehog.Containers.Deployment do
      public? true
      attribute_public? false
      attribute_type :uuid
    end

    belongs_to :ota_operation, Edgehog.OSManagement.OTAOperation do
      public? true
      attribute_public? false
      attribute_type :uuid
    end
  end

  postgres do
    table "campaign_targets"

    references do
      reference :device, on_delete: :delete
      reference :campaign, on_delete: :delete
      reference :deployment, on_delete: :nilify
      reference :ota_operation, on_delete: :delete
    end
  end
end
