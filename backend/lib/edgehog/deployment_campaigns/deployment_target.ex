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

defmodule Edgehog.DeploymentCampaigns.DeploymentTarget do
  @moduledoc """
  Represents a DeploymentTarget.

  Deployment targets are the targets of a Deployment Campaign, which \
  is composed by the target device and the state of the target in the \
  linked Deployment Campaign.
  """
  use Edgehog.MultitenantResource,
    domain: Edgehog.DeploymentCampaigns,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Release
  alias Edgehog.DeploymentCampaigns.DeploymentTarget
  alias Edgehog.DeploymentCampaigns.DeploymentTarget.Changes

  resource do
    description @moduledoc
  end

  graphql do
    type :deployment_target
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
      argument :deployment_campaign_id, :uuid, allow_nil?: false

      prepare build(load: [device: :online])
      prepare build(sort: [latest_attempt: :asc_nils_first])
      prepare build(limit: 1)

      filter expr(deployment_campaign_id == ^arg(:deployment_campaign_id))
      filter expr(status == :idle)
      filter expr(device.online == true)
    end

    read :read_in_progress_targets do
      description """
      Reads all the targets of a deployment campaign that have `in_progress`
      status. This is useful when resuming an deployment campaign to know which
      targets need to setup a retry timeout.
      """

      argument :deployment_campaign_id, :uuid, allow_nil?: false

      filter expr(deployment_campaign_id == ^arg(:deployment_campaign_id))
      filter expr(status == :in_progress)
    end

    create :create do
      description "Creates a new update target."
      primary? true

      accept [:status, :deployment_campaign_id, :device_id]
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

    update :deploy do
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
      change Changes.Deploy
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, DeploymentTarget.Status do
      description "The status of the update target."
      public? true
      allow_nil? false
    end

    attribute :retry_count, :integer do
      description """
      The number of retries of the deployment target. This indicated how many times
      Edgehog retried to send all the necessary information about a deployment towards
      the device without receiving acks.
      """

      public? true
      allow_nil? false
      constraints min: 0
      default 0
    end

    attribute :latest_attempt, :utc_datetime_usec do
      description """
      The timestamp of the latest attempt to deploy to the update target.\
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

    timestamps()
  end

  relationships do
    belongs_to :deployment_campaign, Edgehog.DeploymentCampaigns.DeploymentCampaign do
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
  end

  postgres do
    table "deployment_target"
  end
end
