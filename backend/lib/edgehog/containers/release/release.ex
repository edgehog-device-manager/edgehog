#
# This file is part of Edgehog.
#
# Copyright 2024 - 2026 SECO Mind Srl
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

defmodule Edgehog.Containers.Release do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Changes
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Release.Deployment
  alias Edgehog.Containers.Validations.Dangling
  alias Edgehog.Containers.Validations.UniquePlainResource
  alias Edgehog.Validations

  graphql do
    type :release

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :release do
        action_types [:create, :destroy]
      end
    end

    paginate_relationship_with containers: :relay,
                               deployments: :relay,
                               container_dependencies: :relay
  end

  actions do
    defaults [:read]

    read :plain_releases do
      pagination offset?: true, keyset?: true, required?: false
      filter expr(not exists(deployments, true))
    end

    read :deployed_releases do
      pagination offset?: true, keyset?: true, required?: false
      filter expr(exists(deployments, true))
    end

    create :create do
      primary? true

      accept [:application_id, :version]

      argument :containers, {:array, :map}
      argument :container_dependencies, {:array, :map}

      argument :required_system_models, {:array, :map}

      change manage_relationship(:containers,
               on_no_match: :error,
               on_match: :ignore,
               on_lookup: :relate
             )

      change manage_relationship(:required_system_models, :system_models, type: :append)

      change manage_relationship(:container_dependencies, type: :create)

      validate {UniquePlainResource,
                keys: [:version, :application_id], read_action: :plain_releases, field: :version}

      validate Release.Validations.NoCircularDependencies
    end

    create :copy do
      argument :release, :struct do
        constraints instance_of: __MODULE__
        allow_nil? false
      end

      change Release.Changes.Copy

      validate Release.Validations.NoCircularDependencies
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      validate Release.Validations.CheckDeployments

      change {Changes.MaybeDestroyChildren, children: [:containers]}
    end

    destroy :destroy_if_dangling do
      require_atomic? false

      validate Dangling
      validate Release.Validations.CheckDeployments

      change {Changes.MaybeDestroyChildren, children: [:containers]}
    end
  end

  validations do
    validate {Validations.Version, attribute: :version} do
      where changing(:version)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :version, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :application, Edgehog.Containers.Application do
      attribute_type :uuid
      public? true
    end

    has_many :deployments, Deployment do
      public? true
    end

    many_to_many :devices, Edgehog.Devices.Device do
      through Deployment
      join_relationship :deployments
    end

    many_to_many :containers, Edgehog.Containers.Container do
      through Edgehog.Containers.ReleaseContainers

      source_attribute_on_join_resource :release_id
      destination_attribute_on_join_resource :container_id

      public? true
    end

    has_many :container_dependencies,
             Edgehog.Containers.ReleaseContainerDependencies do
      source_attribute :id
      destination_attribute :release_id

      public? true
    end

    many_to_many :system_models, Edgehog.Devices.SystemModel do
      through Edgehog.Containers.ReleaseSystemModel
      public? true
    end
  end

  calculations do
    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :deployments]}
  end

  postgres do
    table "application_releases"
  end
end
