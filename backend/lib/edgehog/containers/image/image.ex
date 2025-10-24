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

defmodule Edgehog.Containers.Image do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Image.Calculations
  alias Edgehog.Containers.ImageCredentials
  alias Edgehog.Containers.ManualActions

  graphql do
    type :image
    paginate_relationship_with devices: :relay
  end

  actions do
    defaults [:read, :destroy, create: [:reference, :image_credentials_id]]

    destroy :destroy_if_dangling do
      description "Destroys the image if it's dangling (not referenced by any container)"

      manual ManualActions.DestroyIfDangling
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :reference, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :credentials, ImageCredentials do
      source_attribute :image_credentials_id
      attribute_type :uuid
      public? true
    end

    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.Image.Deployment
      join_relationship :image_deployments
      public? true
    end

    has_many :containers, Container do
      public? true
    end
  end

  calculations do
    calculate :dangling?, :boolean, Calculations.Dangling do
      description "Returns true if this image has no containers referring to it"
    end
  end

  identities do
    identity :reference_credentials, [:reference, :image_credentials_id]
  end

  postgres do
    table "images"
  end
end
