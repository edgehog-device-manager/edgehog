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

defmodule Edgehog.Containers.Release.Deployment.ReadyAction.Upgrade do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers

  actions do
    defaults [:read, :destroy, create: [:upgrade_target_id]]
  end

  attributes do
    uuid_primary_key :id
  end

  relationships do
    belongs_to :upgrade_target, Edgehog.Containers.Release.Deployment do
      allow_nil? false
      attribute_type :uuid
    end
  end

  postgres do
    table "deployment_ready_action_upgrades"
  end
end
