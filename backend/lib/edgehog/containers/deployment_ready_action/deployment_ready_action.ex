#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.DeploymentReadyAction do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers

  alias Edgehog.Containers.ManualActions

  actions do
    defaults [:read, :destroy]

    create :create_deployment do
      accept [:action_type]

      argument :action_arguments, :map

      argument :deployment, :map

      change manage_relationship(:deployment,
               on_lookup: :relate,
               use_identities: [:_primary_key, :release_instance],
               on_no_match: {:create, :deploy},
               on_match: :ignore
             )

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
    belongs_to :deployment, Edgehog.Containers.Deployment do
      allow_nil? false
      attribute_type :uuid
    end

    belongs_to :upgrade_deployment, Edgehog.Containers.DeploymentReadyAction.Upgrade do
      attribute_type :uuid
    end
  end

  postgres do
    table "deployment_ready_actions"
  end
end
