#
# This file is part of Edgehog.
#
# Copyright 2024-2026 SECO Mind Srl
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

defmodule Edgehog.Containers.Release.Deployment.ReadyAction do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers

  alias Edgehog.Containers.ManualActions
  alias Edgehog.Containers.Release.Deployment.ReadyAction.Changes

  actions do
    defaults [:read, :destroy]

    create :create_deployment do
      accept [:action_type]

      argument :action_arguments, :map

      argument :deployment, :map

      change Changes.CreateDeployment
      change ManualActions.DeploymentReadyActionAddRelationship
    end

    update :run do
      manual ManualActions.RunReadyAction
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :action_type, :atom do
      constraints one_of: [:upgrade_deployment]
      allow_nil? false
    end
  end

  relationships do
    belongs_to :deployment, Edgehog.Containers.Release.Deployment do
      allow_nil? false
      attribute_type :uuid
    end

    has_one :upgrade_deployment, Edgehog.Containers.Release.Deployment.ReadyAction.Upgrade do
      destination_attribute :deployment_ready_action_id
    end
  end

  postgres do
    table "deployment_ready_actions"

    references do
      reference :deployment, on_delete: :delete
    end
  end
end
