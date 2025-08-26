#
# This file is part of Edgehog.
#
# Copyright 2022-2025 SECO Mind Srl
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

defmodule Edgehog.Groups.DeviceGroup do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Groups,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.Groups.DeviceGroup.ManualRelationships
  alias Edgehog.Groups.DeviceGroup.Validations

  graphql do
    type :device_group
  end

  actions do
    defaults [:read]

    create :create do
      description "Creates a new device group."
      primary? true

      accept [:name, :handle, :selector]
    end

    update :update do
      description "Updates a device group."
      primary? true

      # Needed because resource's validations are not atomic
      require_atomic? false

      accept [:name, :handle, :selector]
    end

    update :update_update_channel do
      # Needed because resource's validations are not atomic
      require_atomic? false

      accept [:update_channel_id]
    end

    update :assign_update_channel do
      accept [:update_channel_id]

      require_atomic? false

      validate Validations.UpdateChannelAbsent
    end

    update :assign_deployment_channel do
      accept [:deployment_channel_id]

      require_atomic? false

      validate Validations.DeploymentChannelAbsent
    end

    destroy :destroy do
      description "Deletes a device group."
      primary? true
    end
  end

  validations do
    validate Edgehog.Validations.slug(:handle) do
      where changing(:handle)
    end

    validate Validations.Selector do
      where changing(:selector)
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      public? true
      description "The display name of the device group."
      allow_nil? false
    end

    attribute :handle, :string do
      public? true

      description """
      The identifier of the device group.

      It should start with a lower case ASCII letter and only contain \
      lower case ASCII letters, digits and the hyphen - symbol.
      """

      allow_nil? false
    end

    # TODO: custom type here
    attribute :selector, :string do
      public? true

      description """
      The Selector that will determine which devices belong to the device group.

      This must be a valid selector expression, consult the Selector section \
      of the Edgehog documentation for more information about Selectors.
      """

      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :devices, Edgehog.Devices.Device do
      public? true
      description "The devices belonging to the group."
      writable? false
      manual ManualRelationships.Devices
    end

    belongs_to :update_channel, Edgehog.UpdateCampaigns.UpdateChannel do
      description "The update channel associated with the group, if present."
      public? true
      attribute_public? false
    end

    belongs_to :deployment_channel, Edgehog.DeploymentCampaigns.DeploymentChannel do
      description "The deployment channel associated with the group, if present."
      public? true
      attribute_public? false
      attribute_type :uuid
    end
  end

  identities do
    identity :name, [:name]
    identity :handle, [:handle]
  end

  postgres do
    table "device_groups"
    repo Edgehog.Repo

    references do
      reference :update_channel, on_delete: :nilify, match_with: [tenant_id: :tenant_id]
    end
  end
end
