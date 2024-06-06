#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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

defmodule Edgehog.Devices.SystemModelPartNumber do
  use Edgehog.MultitenantResource,
    domain: Edgehog.Devices,
    extensions: [
      AshGraphql.Resource
    ]

  graphql do
    type :system_model_part_number

    paginate_relationship_with devices: :relay
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:part_number]
    end

    update :update do
      primary? true
      accept [:part_number]
    end
  end

  attributes do
    integer_primary_key :id

    attribute :part_number, :string do
      public? true
      description "The part number identifier."
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :system_model, Edgehog.Devices.SystemModel do
      public? true
      attribute_public? false
    end

    has_many :devices, Edgehog.Devices.Device do
      source_attribute :part_number
      destination_attribute :part_number
    end
  end

  identities do
    identity :part_number_tenant_id, [:part_number]
  end

  postgres do
    table "system_model_part_numbers"
    repo Edgehog.Repo

    references do
      reference :system_model, on_delete: :delete
    end
  end
end
