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

defmodule Edgehog.Containers.Network do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.ContainerNetwork
  alias Edgehog.Containers.Network.Calculations
  alias Edgehog.Containers.Validations

  graphql do
    type :network
    paginate_relationship_with containers: :relay, devices: :relay
  end

  actions do
    defaults [:read, :destroy, create: [:label, :driver, :internal, :enable_ipv6, :options]]

    destroy :destroy_if_dangling do
      description "Destroys the network if it's dangling (not referenced by any container)"

      require_atomic? false
      validate Validations.Dangling
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      public? true
    end

    attribute :driver, :string do
      default "bridge"
      allow_nil? false
      public? true
    end

    attribute :internal, :boolean do
      default false
      allow_nil? false
      public? true
    end

    attribute :enable_ipv6, :boolean do
      default false
      allow_nil? false
      public? true
    end

    attribute :options, :map do
      allow_nil? false
      default %{}
      public? true
    end

    timestamps()
  end

  relationships do
    many_to_many :containers, Edgehog.Containers.Container do
      through ContainerNetwork
      public? true
    end

    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.Network.Deployment
      join_relationship :network_deployments
      public? true
    end

    has_many :container_networks, ContainerNetwork
  end

  calculations do
    calculate :options_encoding, {:array, :string}, Calculations.OptionsEncoding

    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :containers]}
  end

  identities do
    identity :label, [:label]
  end

  postgres do
    table "networks"
    repo Edgehog.Repo

    references do
      reference :container_networks, on_delete: :restrict, match_with: [tenant_id: :tenant_id]
    end
  end
end
