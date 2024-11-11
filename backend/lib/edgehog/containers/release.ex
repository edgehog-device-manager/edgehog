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

defmodule Edgehog.Containers.Release do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Validations

  graphql do
    type :release
  end

  actions do
    defaults [:read, :destroy, create: [:application_id, :version]]
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

    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.Deployment
      join_relationship :deployments
    end

    many_to_many :containers, Edgehog.Containers.Container do
      through Edgehog.Containers.ReleaseContainers
      public? true
    end
  end

  identities do
    identity :application_version, [:application_id, :version]
  end

  postgres do
    table "application_releases"
  end
end
