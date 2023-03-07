#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.GroupsTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Resolvers

  node object(:device_group) do
    @desc "The display name of the device group."
    field :name, non_null(:string)

    @desc "The handle of the device group."
    field :handle, non_null(:string)

    @desc "The selector of the device group."
    field :selector, non_null(:string)

    @desc "The devices belonging to the group."
    field :devices, non_null(list_of(non_null(:device))) do
      resolve &Resolvers.Groups.devices_for_group/3
    end

    @desc "The UpdateChannel associated with this group, if present."
    field :update_channel, :update_channel do
      resolve &Resolvers.UpdateCampaigns.batched_update_channel_for_device_group/3
    end
  end

  object :groups_queries do
    @desc "Fetches the list of all device groups."
    field :device_groups, non_null(list_of(non_null(:device_group))) do
      resolve &Resolvers.Groups.list_device_groups/2
    end

    @desc "Fetches a single device group."
    field :device_group, :device_group do
      @desc "The ID of the device group."
      arg :id, non_null(:id)

      middleware Absinthe.Relay.Node.ParseIDs, id: :device_group
      resolve &Resolvers.Groups.find_device_group/2
    end
  end

  object :groups_mutations do
    @desc "Creates a new device group."
    payload field :create_device_group do
      input do
        @desc "The display name of the device group."
        field :name, non_null(:string)

        @desc """
        The identifier of the device group.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, non_null(:string)

        @desc """
        The Selector that will determine which devices belong to the device group.

        This must be a valid selector expression, consult the Selector section \
        of the Edgehog documentation for more information about Selectors.
        """
        field :selector, non_null(:string)
      end

      output do
        @desc "The created device group."
        field :device_group, non_null(:device_group)
      end

      resolve &Resolvers.Groups.create_device_group/2
    end

    @desc "Updates a device group."
    payload field :update_device_group do
      input do
        @desc "The ID of the device group to be updated."
        field :device_group_id, non_null(:id)

        @desc "The display name of the device group."
        field :name, :string

        @desc """
        The identifier of the device group.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, :string

        @desc """
        The Selector that will determine which devices belong to the device group.

        This must be a valid selector expression, consult the Selector section \
        of the Edgehog documentation for more information about Selectors.
        """
        field :selector, :string
      end

      output do
        @desc "The updated device group."
        field :device_group, non_null(:device_group)
      end

      middleware Absinthe.Relay.Node.ParseIDs, device_group_id: :device_group
      resolve &Resolvers.Groups.update_device_group/2
    end

    @desc "Deletes a device group."
    payload field :delete_device_group do
      input do
        @desc "The ID of the device group to be deleted."
        field :device_group_id, non_null(:id)
      end

      output do
        @desc "The deleted device group."
        field :device_group, non_null(:device_group)
      end

      middleware Absinthe.Relay.Node.ParseIDs, device_group_id: :device_group
      resolve &Resolvers.Groups.delete_device_group/2
    end
  end
end
