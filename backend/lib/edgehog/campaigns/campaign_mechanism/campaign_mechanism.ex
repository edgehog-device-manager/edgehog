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

defmodule Edgehog.Campaigns.CampaignMechanism do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      storage: :map_with_tag,
      types: [
        deployment_deploy: [
          tag: :type,
          tag_value: :deployment_deploy,
          type: Edgehog.Campaigns.CampaignMechanism.DeploymentDeploy,
          cast_tag?: true
        ],
        deployment_start: [
          tag: :type,
          tag_value: :deployment_start,
          type: Edgehog.Campaigns.CampaignMechanism.DeploymentStart,
          cast_tag?: true
        ],
        deployment_stop: [
          tag: :type,
          tag_value: :deployment_stop,
          type: Edgehog.Campaigns.CampaignMechanism.DeploymentStop,
          cast_tag?: true
        ],
        deployment_delete: [
          tag: :type,
          tag_value: :deployment_delete,
          type: Edgehog.Campaigns.CampaignMechanism.DeploymentDelete,
          cast_tag?: true
        ],
        deployment_upgrade: [
          tag: :type,
          tag_value: :deployment_upgrade,
          type: Edgehog.Campaigns.CampaignMechanism.DeploymentUpgrade,
          cast_tag?: true
        ],
        firmware_upgrade: [
          tag: :type,
          tag_value: :firmware_upgrade,
          type: Edgehog.Campaigns.CampaignMechanism.FirmwareUpgrade,
          cast_tag?: true
        ]
      ]
    ]

  use AshGraphql.Type

  @impl AshGraphql.Type
  def graphql_type(_), do: :campaign_mechanism

  @impl AshGraphql.Type
  def graphql_unnested_unions(_constraints),
    do: [
      :deployment_deploy,
      :deployment_start,
      :deployment_stop,
      :deployment_delete,
      :deployment_upgrade,
      :firmware_upgrade
    ]
end
