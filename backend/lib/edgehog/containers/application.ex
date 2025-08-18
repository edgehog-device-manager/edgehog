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

defmodule Edgehog.Containers.Application do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  graphql do
    type :application
    paginate_relationship_with releases: :relay
  end

  actions do
    defaults [:read, update: [:name, :description]]

    destroy :destroy do
      primary? true
      require_atomic? false
      change Edgehog.Containers.Changes.DestroyRelatedReleases
    end

    create :create do
      primary? true
      accept [:name, :description]

      argument :initial_release, :map
      argument :system_model_id, :id

      change manage_relationship(:initial_release, :releases, type: :create)
      change manage_relationship(:system_model_id, :system_model, type: :append)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :releases, Edgehog.Containers.Release do
      public? true
    end

    belongs_to :system_model, Edgehog.Devices.SystemModel do
      public? true
    end
  end

  identities do
    identity :name_and_system_model, [:name, :system_model_id] do
      description "name and system model association identity"
    end
  end

  postgres do
    table "applications"
  end
end
