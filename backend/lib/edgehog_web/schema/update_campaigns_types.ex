#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.UpdateCampaignsTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias Edgehog.UpdateCampaigns.PushRollout
  alias EdgehogWeb.Resolvers

  @desc """
  Represents an UpdateChannel.

  An UpdateChannel represents a set of TargetGroups that can be targeted in an \
  UpdateCampaign
  """
  node object(:update_channel) do
    @desc "The display name of the target group."
    field :name, non_null(:string)

    @desc "The identifier of the target group."
    field :handle, non_null(:string)

    @desc "The DeviceGroups associated with this UpdateChannel"
    field :target_groups, non_null(list_of(non_null(:device_group)))
  end

  @desc """
  An object representing the properties of a Push Rollout Mechanism
  """
  object :push_rollout do
    @desc """
    The maximum percentage of errors allowed over the number of total targets. \
    If the errors exceed this threshold, the Update Campaign terminates with \
    an error.
    """
    field :max_errors_percentage, non_null(:float)

    @desc """
    The maximum number of in progress updates. The Update Campaign will have \
    at most this number of OTA Operations that are started but not yet \
    finished (either successfully or not).
    """
    field :max_in_progress_updates, non_null(:integer)

    @desc """
    The number of attempts that have to be tried before giving up on the \
    update of a specific target (and considering it an error). Note that the \
    update is retried only if the OTA Request doesn't get acknowledged from the \
    device.
    """
    field :ota_request_retries, non_null(:integer)

    @desc """
    The timeout (in seconds) Edgehog has to wait before considering an OTA \
    Request lost (and possibly retry). It must be at least 30 seconds.
    """
    field :ota_request_timeout_seconds, non_null(:integer)

    @desc """
    This boolean flag determines if the Base Image will be pushed to the \
    Device even if it already has a greater version of the Base Image.
    """
    field :force_downgrade, non_null(:boolean)
  end

  @desc """
  A Rollout Mechanism used by an Update Campaign
  """
  union :rollout_mechanism do
    # This just has a single type for now, but we use a union to leave space
    # for extension when we introduce new rollout mechanisms
    types [:push_rollout]

    resolve_type fn
      %PushRollout{}, _ -> :push_rollout
    end
  end

  @desc """
  The status of an Update Target
  """
  enum :update_target_status do
    @desc "The Update Campaign is waiting for the OTA Request to be sent"
    value :idle
    @desc "The Update Target is being updated"
    value :pending
    @desc "The Update Target has failed to be updated"
    value :failed
    @desc "The Update Target was successfully updated"
    value :successful
  end

  @desc """
  Represents an UpdateTarget.

  An Update Target is the target of an Update Campaign, which is composed by \
  the targeted device and the status of the target in the linked Update \
  Campaign.
  """
  node object(:update_target) do
    @desc "The status of the Update Target."
    field :status, non_null(:update_target_status)

    @desc "The Target device."
    field :device, non_null(:device)
  end

  @desc """
  The status of an Update Campaign
  """
  enum :update_campaign_status do
    @desc "The Update Campaign is being rolled-out"
    value :in_progress
    @desc "The Update Campaign has finished"
    value :finished
  end

  @desc """
  The outcome of an Update Campaign
  """
  enum :update_campaign_outcome do
    @desc "The Update Campaign has finished succesfully"
    value :success
    @desc "The Update Campaign has finished with a failure"
    value :failure
  end

  @desc """
  Represents an UpdateCampaign.

  An Update Campaign is the operation that tracks the distribution of a \
  specific Base Image to all devices belonging to an Update Channel.
  """
  node object(:update_campaign) do
    @desc "The name of the Update Campaign."
    field :name, non_null(:string)

    @desc "The status of the Update Campaign."
    field :status, non_null(:update_campaign_status)

    @desc "The outcome of the Update Campaign, present only when it's finished."
    field :outcome, :update_campaign_outcome

    @desc "The Rollout Mechanism used in the Update Campaign."
    field :rollout_mechanism, non_null(:rollout_mechanism)

    @desc "The Base Image distributed in the Update Campaign."
    field :base_image, non_null(:base_image)

    @desc "The Update Channel targeted by the Update Campaign."
    field :update_channel, non_null(:update_channel)

    @desc "The Targets that will receive the update during the Update Campaign."
    field :update_targets, non_null(list_of(non_null(:update_target)))
  end

  object :update_campaigns_queries do
    @desc "Fetches the list of all update channels."
    field :update_channels, non_null(list_of(non_null(:update_channel))) do
      resolve &Resolvers.UpdateCampaigns.list_update_channels/2
    end

    @desc "Fetches a single update channel."
    field :update_channel, :update_channel do
      @desc "The ID of the update channel."
      arg :id, non_null(:id)

      middleware Absinthe.Relay.Node.ParseIDs, id: :update_channel
      resolve &Resolvers.UpdateCampaigns.find_update_channel/2
    end
  end

  object :update_campaigns_mutations do
    @desc "Creates a new update channel."
    payload field :create_update_channel do
      input do
        @desc "The display name of the update channel."
        field :name, non_null(:string)

        @desc """
        The identifier of the update channel.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, non_null(:string)

        @desc """
        The IDs of the target groups that are targeted by this update channel
        """
        field :target_group_ids, non_null(list_of(non_null(:id)))
      end

      output do
        @desc "The created update channel."
        field :update_channel, non_null(:update_channel)
      end

      middleware Absinthe.Relay.Node.ParseIDs, target_group_ids: :device_group

      resolve &Resolvers.UpdateCampaigns.create_update_channel/2
    end

    @desc "Updates an update channel."
    payload field :update_update_channel do
      input do
        @desc "The ID of the update channel to be updated"
        field :update_channel_id, non_null(:id)

        @desc "The updated display name of the update channel."
        field :name, :string

        @desc """
        The updated identifier of the update channel.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, :string

        @desc """
        The updated IDs of the target groups that are targeted by this update \
        channel
        """
        field :target_group_ids, list_of(non_null(:id))
      end

      output do
        @desc "The updated update channel."
        field :update_channel, non_null(:update_channel)
      end

      middleware Absinthe.Relay.Node.ParseIDs,
        update_channel_id: :update_channel,
        target_group_ids: :device_group

      resolve &Resolvers.UpdateCampaigns.update_update_channel/2
    end

    @desc "Deletes an update channel."
    payload field :delete_update_channel do
      input do
        @desc "The ID of the update channel to be deleted."
        field :update_channel_id, non_null(:id)
      end

      output do
        @desc "The deleted update channel."
        field :update_channel, non_null(:update_channel)
      end

      middleware Absinthe.Relay.Node.ParseIDs, update_channel_id: :update_channel
      resolve &Resolvers.UpdateCampaigns.delete_update_channel/2
    end
  end
end
