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

defmodule Edgehog.DeploymentCampaigns.DeploymentCampaign do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.DeploymentCampaigns,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Campaigns.Outcome
  alias Edgehog.Campaigns.Status
  alias Edgehog.Containers.Release

  graphql do
    type :deployment_campaign
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

    attribute :status, Status do
      description "The status of the deployment campaign."
      public? true
      allow_nil? false
    end

    attribute :outcome, Outcome do
      description "The outcome of the deployment campaign."
      public? true
    end

    attribute :start_timestamp, :utc_datetime_usec
    attribute :completion_timestamp, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :release, Release do
      description "The release distributed by the deployment campaign."
      public? true
      attribute_public? false
      attribute_type :uuid
      allow_nil? false
    end
  end

  postgres do
    table "deployment_campaign"
  end
end
