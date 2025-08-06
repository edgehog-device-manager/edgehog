#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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
    extensions: [AshGraphql.Resource],
    authorizers: [Ash.Policy.Authorizer]

  graphql do
    type :application
    paginate_relationship_with releases: :relay
  end

  actions do
    defaults [:read, :destroy, update: [:name, :description]]

    create :create do
      primary? true
      accept [:name, :description]

      argument :initial_release, :map

      change manage_relationship(:initial_release, :releases, type: :create)
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
  end

  identities do
    identity :name, [:name]
  end

  postgres do
    table "applications"
  end
end
