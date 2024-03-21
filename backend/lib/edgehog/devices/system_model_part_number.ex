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
    api: Edgehog.Devices,
    extensions: [
      AshGraphql.Resource
    ]

  graphql do
    type :system_model_part_number

    hide_fields [:tenant]
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  attributes do
    integer_primary_key :id

    attribute :part_number, :string do
      description "The part number identifier."
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :system_model, Edgehog.Devices.SystemModel

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
