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

defmodule Edgehog.Containers.Network do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Network.OptionsCalculation

  graphql do
    type :network
  end

  actions do
    defaults [:read, :destroy, create: [:driver, :internal, :enable_ipv6, :options]]
  end

  attributes do
    uuid_primary_key :id

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
      through Edgehog.Containers.ContainerNetwork
    end

    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.Network.Deployment
      join_relationship :network_deployments
    end
  end

  calculations do
    calculate :options_encoding, {:array, :string}, OptionsCalculation
  end

  postgres do
    table "networks"
  end
end
