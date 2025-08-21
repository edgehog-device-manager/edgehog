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
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.DeploymentCampaigns,
    extensions: [AshGraphql.Resource]

  graphql do
    type :deployment_target
  end

  actions do
    defaults [:read]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :retry_count, :integer do
      public? true
      allow_nil? false
    end

    attribute :latest_attempt, :utc_datetime_usec do
      public? true
    end

    attribute :completion_timestamp, :utc_datetime_usec do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :deployment_campaign, Edgehog.DeploymentCampaigns.DeploymentCampaign do
      public? true
      allow_nil? false
    end

    belongs_to :device, Edgehog.Devices.Device do
      public? true
      allow_nil? false
    end

    belongs_to :deployment, Edgehog.Containers.Deployment do
      public? true
      allow_nil? false
    end
  end
end
