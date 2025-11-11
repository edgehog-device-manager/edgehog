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

defmodule Edgehog.Containers.Volume do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Validations

  graphql do
    type :volume
    paginate_relationship_with devices: :relay
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:label, :driver, :options],
      update: [:driver, :options]
    ]

    destroy :destroy_if_dangling do
      description "Destroys the volume if it's dangling (not referenced by any container)"

      require_atomic? false
      validate Validations.Dangling
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      allow_nil? false
      public? true
    end

    attribute :driver, :string do
      default "local"
      allow_nil? false
      public? true
    end

    attribute :options, :map do
      default %{}
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.Volume.Deployment
      join_relationship :volume_deployments
      public? true
    end

    has_many :container_volumes, Edgehog.Containers.ContainerVolume
  end

  calculations do
    calculate :options_encoding,
              {:array, :string},
              Edgehog.Containers.Calculations.OptionsEncoding

    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :containers]}
  end

  identities do
    identity :label, [:label]
  end

  postgres do
    table "volumes"
    repo Edgehog.Repo

    references do
      reference :container_volumes, on_delete: :restrict, match_with: [tenant_id: :tenant_id]
    end
  end
end
