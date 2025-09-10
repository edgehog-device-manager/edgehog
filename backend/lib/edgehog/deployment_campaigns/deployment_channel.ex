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

defmodule Edgehog.DeploymentCampaigns.DeploymentChannel do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.DeploymentCampaigns,
    extensions: [AshGraphql.Resource]

  alias Edgehog.DeploymentCampaigns.DeploymentChannel.Calculations

  resource do
    description """
    Represents a DeploymentChannel.

    A DeploymentChannel represents a set of device groups that can be targeted in
    a DeploymentCampaign.
    """
  end

  graphql do
    type :deployment_channel
  end

  actions do
    defaults [:read]

    create :create do
      description "Creates a new deployment channel."
      primary? true

      accept [:name, :handle]

      argument :target_group_ids, {:array, :id} do
        description """
        The IDs of the target groups that are targeted by this update channel.
        """
      end

      change manage_relationship(:target_group_ids, :target_groups,
               on_lookup: {:relate, :assign_deployment_channel},
               on_no_match: :error
             ) do
        where present(:target_group_ids)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :handle, :string do
      public? true
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    has_many :target_groups, Edgehog.Groups.DeviceGroup do
      public? true
    end

    has_many :deployment_campaigns, Edgehog.DeploymentCampaigns.DeploymentCampaign do
      public? true
    end
  end

  calculations do
    calculate :deployable_devices, {:array, :struct} do
      description """
      The devices targeted by the deployment channel that can be updated with the
      provided release. Note that this only checks the compatibility between the
      device and the system model targeted by the release. The starting version
      requirement will be checked just before the update and will potentially
      result in a failed operation.
      """

      constraints items: [instance_of: Edgehog.Devices.Device]
      allow_nil? false

      argument :release, :struct do
        allow_nil? false
        constraints instance_of: Edgehog.Containers.Release
      end

      calculation Calculations.DeployableDevices
    end
  end

  postgres do
    table "deployment_channels"
  end
end
