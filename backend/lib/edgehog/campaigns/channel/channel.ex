#
# This file is part of Edgehog.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Edgehog.Campaigns.Channel do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Campaigns,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.Campaigns.Channel.Calculations
  alias Edgehog.Campaigns.Channel.Changes
  alias Edgehog.Campaigns.Channel.ErrorHandler
  alias Edgehog.Devices.Device

  resource do
    description """
    Represents an Channel.

    An Channel represents a set of device groups that can be targeted in \
    an Campaign.
    """
  end

  graphql do
    type :channel

    error_handler {ErrorHandler, :handle_error, []}

    paginate_relationship_with target_groups: :relay, campaigns: :relay
  end

  actions do
    defaults [:read]

    create :create do
      description "Creates a new channel."
      primary? true

      accept [:name, :handle]

      argument :target_group_ids, {:array, :id} do
        description """
        The IDs of the target groups that are targeted by this channel.
        """
      end

      change Changes.RelateTargetGroups do
        where present(:target_group_ids)
      end
    end

    update :update do
      description "Updates an channel."
      primary? true

      accept [:name, :handle]

      argument :target_group_ids, {:array, :id} do
        description """
        The IDs of the target groups that are targeted by this channel.
        """
      end

      # Needed because manage_relationship is not atomic
      require_atomic? false

      change Changes.UnrelateCurrentTargetGroups do
        where present(:target_group_ids)
      end

      change Changes.RelateTargetGroups do
        where present(:target_group_ids)
      end
    end

    destroy :destroy do
      description "Deletes an channel."
      primary? true

      # Needed because Changes.UnrelateTargetGroups is not atomic
      require_atomic? false

      # TODO: here we manually unrelate the channel from its target
      # groups. Indeed, the database constraints on the device_groups table are
      # configured so that the (tenant_id, channel_id) foreign key is
      # set to NULL when the referenced channel is deleted. However that
      # would also set the tenant_id of the target group to NULL.
      # Postgres v15.0 introduced the possibility to specify which columns of
      # the foreign key should be set to NULL when the referenced resource is
      # deleted; if they are not specified, they are all set to NULL as usual.
      # Since we don't want to impose the use of Postgres v15+, for now we
      # simply avoid triggering the ON DELETE database constraint by manually
      # setting the correct columns to NULL before deleting the referenced
      # channel: i.e. without affecting the tenant_id of device groups.
      change Changes.UnrelateCurrentTargetGroups
    end
  end

  validations do
    validate Edgehog.Validations.slug(:handle) do
      where changing(:handle)
    end
  end

  attributes do
    integer_primary_key :id

    attribute :handle, :string do
      description """
      The identifier of the channel.

      It should start with a lower case ASCII letter and only contain \
      lower case ASCII letters, digits and the hyphen - symbol.
      """

      public? true
      allow_nil? false
    end

    attribute :name, :string do
      description "The display name of the channel."
      public? true
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :target_groups, Edgehog.Groups.DeviceGroup do
      description "The device groups targeted by the channel."
      public? true
    end

    # This is needed to ensure foreign key references are applied when deleting
    # base images so we can render a nice looking error instead of crashing, see
    # https://github.com/ash-project/ash_postgres/blob/0ccb35a713b9097c4aac6fde996dbb4d1c00cccb/lib/data_layer.ex#L2370
    has_many :campaigns, Edgehog.Campaigns.Campaign do
      public? true
    end
  end

  calculations do
    calculate :updatable_devices, {:array, :struct} do
      description """
      The devices targeted by the channel that can be updated with the \
      provided base image.
      Note that this only checks the compatibility between the device and the \
      system model targeted by the base image. The starting version \
      requirement will be checked just before the update and will potentially \
      result in a failed operation.\
      """

      constraints items: [instance_of: Device]
      allow_nil? false

      argument :base_image, :struct do
        allow_nil? false
        constraints instance_of: Edgehog.BaseImages.BaseImage
      end

      calculation Calculations.UpdatableDevices
    end

    calculate :deployable_devices, {:array, :struct} do
      description """
      The devices targeted by the deployment channel that can be updated with the
      provided release. Note that this only checks the compatibility between the
      device and the system model targeted by the release. The starting version
      requirement will be checked just before the update and will potentially
      result in a failed operation.
      """

      constraints items: [instance_of: Device]
      allow_nil? false

      argument :release, :struct do
        allow_nil? false
        constraints instance_of: Edgehog.Containers.Release
      end

      calculation Calculations.DeployableDevices
    end
  end

  identities do
    identity :handle, [:handle]
    identity :name, [:name]
  end

  postgres do
    table "channels"
    repo Edgehog.Repo
  end
end
