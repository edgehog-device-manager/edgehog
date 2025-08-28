#
# This file is part of Edgehog.
#
# Copyright 2021 - 2025 SECO Mind Srl
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

defmodule Edgehog.Devices.HardwareType do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Devices,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.Validations

  resource do
    description """
    Denotes a type of hardware that devices can have.

    It refers to the physical components embedded in a device.
    This can represent, e.g., multiple revisions of a PCB (each with a
    different part number) which are functionally equivalent from the device
    point of view.
    """
  end

  graphql do
    type :hardware_type

    paginate_relationship_with part_numbers: :relay
  end

  actions do
    defaults [:read]

    create :create do
      description "Creates a hardware type."
      primary? true

      accept [:handle, :name]

      argument :part_numbers, {:array, :string} do
        allow_nil? false
        constraints min_length: 1
      end

      # TODO: see issue #228, which is still relevant
      change manage_relationship(:part_numbers,
               on_lookup: :relate,
               on_no_match: :create,
               value_is_key: :part_number,
               use_identities: [:part_number]
             )
    end

    update :update do
      description "Updates a hardware type."
      primary? true

      # Needed because manage_relationship is not atomic
      require_atomic? false

      accept [:handle, :name]

      argument :part_numbers, {:array, :string} do
        description "The list of part numbers associated with the hardware type."
        constraints min_length: 1
      end

      change manage_relationship(:part_numbers,
               on_lookup: :relate,
               on_no_match: :create,
               on_missing: :unrelate,
               value_is_key: :part_number,
               use_identities: [:part_number]
             )
    end

    destroy :destroy do
      description "Deletes a hardware type."
      primary? true
    end
  end

  validations do
    validate Validations.slug(:handle) do
      where changing(:handle)
    end
  end

  attributes do
    integer_primary_key :id

    attribute :handle, :string do
      public? true

      description """
      The identifier of the hardware type.

      It should start with a lower case ASCII letter and only contain \
      lower case ASCII letters, digits and the hyphen - symbol.
      """

      allow_nil? false
    end

    attribute :name, :string do
      public? true
      description "The display name of the hardware type."
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :part_numbers, Edgehog.Devices.HardwareTypePartNumber do
      public? true
      description "The list of part numbers associated with the hardware type."
    end

    # TODO: :system_model
  end

  aggregates do
    list :part_number_strings, :part_numbers, :part_number
  end

  identities do
    identity :handle, [:handle]
    identity :name, [:name]
  end

  postgres do
    table "hardware_types"
    repo Edgehog.Repo
  end
end
