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

defmodule Edgehog.Containers.Container.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  graphql do
    type :container_deployment
  end

  actions do
    defaults [:read, :destroy, create: [:status], update: [:status]]
  end

  attributes do
    uuid_primary_key :id

    attribute :status, Edgehog.Containers.Container.Status do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :container, Edgehog.Containers.Container do
      attribute_type :uuid
      public? true
    end

    belongs_to :device, Edgehog.Devices.Device
  end

  identities do
    identity :container_instance, [:container_id, :device_id]
  end

  postgres do
    table "application_container_deployments"
  end
end
