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
  end
end
