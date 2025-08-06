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

defmodule Edgehog.Containers.Container do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Container.EnvEncoding
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Types.RestartPolicy

  graphql do
    type :container

    paginate_relationship_with networks: :relay,
                               devices: :relay,
                               volumes: :relay,
                               releases: :relay
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :port_bindings,
        :restart_policy,
        :hostname,
        :network_mode,
        :env,
        :privileged,
        :image_id
      ],
      update: [
        :port_bindings,
        :restart_policy,
        :hostname,
        :network_mode,
        :env,
        :privileged,
        :image_id
      ]
    ]

    create :create_with_nested do
      accept [:restart_policy, :hostname, :env, :privileged, :port_bindings, :network_mode]

      argument :image, :map

      change manage_relationship(:image,
               on_no_match: :create,
               on_lookup: :relate,
               on_match: :ignore,
               use_identities: [:reference]
             )
    end

    create :create_fixture do
      accept [
        :port_bindings,
        :restart_policy,
        :hostname,
        :network_mode,
        :env,
        :privileged,
        :image_id
      ]

      argument :volumes, {:array, :map}

      change manage_relationship(:volumes,
               on_no_match: {:create, :create, :create, [:target]},
               on_lookup: {:relate, :create}
             )
    end

    read :filter_by_image do
      argument :image_id, :uuid

      filter expr(image_id == ^arg(:image_id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :restart_policy, RestartPolicy do
      public? true
    end

    attribute :port_bindings, {:array, :string} do
      default []
      allow_nil? false
      public? true
    end

    attribute :hostname, :string do
      constraints allow_empty?: true
      default ""
      allow_nil? false
      public? true
    end

    attribute :env, :map do
      default %{}
      public? true
    end

    attribute :privileged, :boolean do
      default false
      public? true
    end

    attribute :network_mode, :string do
      default "bridge"
      public? true
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :image, Image do
      source_attribute :image_id
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    many_to_many :releases, Edgehog.Containers.Release do
      through Edgehog.Containers.ReleaseContainers
      public? true
    end

    many_to_many :volumes, Edgehog.Containers.Volume do
      through Edgehog.Containers.ContainerVolume
      join_relationship :container_volumes
      public? true
    end

    many_to_many :networks, Edgehog.Containers.Network do
      through Edgehog.Containers.ContainerNetwork
      public? true
    end

    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.Container.Deployment
      join_relationship :container_deployments
      public? true
    end
  end

  calculations do
    calculate :env_encoding, :vector, EnvEncoding
  end

  postgres do
    table "containers"
  end
end
