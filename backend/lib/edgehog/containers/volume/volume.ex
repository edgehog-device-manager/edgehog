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

defmodule Edgehog.Containers.Volume do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Validations

  graphql do
    type :volume

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :volume do
        actions [:create, :update, :destroy]
      end
    end

    paginate_relationship_with devices: :relay
  end

  actions do
    defaults [
      :read,
      :destroy
    ]

    create :create do
      primary? true
      accept [:label, :driver, :options]

      validate {Validations.UniquePlainResource,
                keys: [:label], read_action: :plain_volumes, field: :label}
    end

    create :copy do
      accept [:label, :driver, :options, :source_volume_id]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:label, :driver, :options]

      validate {Validations.UniquePlainResource,
                keys: [:label], read_action: :plain_volumes, field: :label}
    end

    read :plain_volumes do
      pagination offset?: true, keyset?: true, required?: false
      filter expr(not exists(volume_deployments, true))
    end

    read :deployed_volumes do
      pagination offset?: true, keyset?: true, required?: false
      filter expr(exists(volume_deployments, true))
    end

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
    belongs_to :source_volume, __MODULE__ do
      attribute_type :uuid
      allow_nil? true
    end

    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.Volume.Deployment
      join_relationship :volume_deployments
      public? true
    end

    many_to_many :containers, Edgehog.Containers.Container do
      through Edgehog.Containers.ContainerVolume
      join_relationship :container_volumes
      public? true
    end
  end

  calculations do
    calculate :options_encoding,
              {:array, :string},
              Edgehog.Containers.Calculations.OptionsEncoding

    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :containers]}

    calculate :hash,
              :string,
              {Edgehog.Containers.Calculations.Hash, fields: [:label, :driver, :options]} do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :copied_volume, [:source_volume_id, :label, :driver]
  end

  postgres do
    table "volumes"
    repo Edgehog.Repo
    skip_unique_indexes [:copied_volume]

    references do
      reference :source_volume, on_delete: :nilify
    end
  end
end
