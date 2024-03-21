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

defmodule Edgehog.Devices.HardwareType do
  use Edgehog.MultitenantResource,
    api: Edgehog.Devices,
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

    hide_fields [:tenant, :part_number_strings]

    queries do
      get :hardware_type, :get
      list :hardware_types, :list
    end

    mutations do
      create :create_hardware_type, :create
      update :update_hardware_type, :update
      destroy :delete_hardware_type, :destroy
    end
  end

  actions do
    read :get do
      description "Returns a hardware type."
      get? true
    end

    read :list do
      description "Returns a list of hardware types."
      primary? true
    end

    create :create do
      description "Creates a hardware type."
      primary? true

      argument :part_numbers, {:array, :string} do
        allow_nil? false
        constraints min_length: 1
      end

      # TODO: see issue #228, which is still relevant
      change manage_relationship(:part_numbers,
               on_lookup: :relate,
               on_no_match: :create,
               value_is_key: :part_number,
               use_identities: [:part_number_tenant_id]
             )
    end

    update :update do
      description "Updates a hardware type."
      primary? true

      argument :part_numbers, {:array, :string} do
        description "The list of part numbers associated with the hardware type."
        constraints min_length: 1
      end

      change manage_relationship(:part_numbers,
               on_lookup: :relate,
               on_no_match: :create,
               on_missing: :unrelate,
               value_is_key: :part_number,
               use_identities: [:part_number_tenant_id]
             )
    end

    destroy :destroy do
      description "Deletes a hardware type."
      primary? true
    end
  end

  attributes do
    integer_primary_key :id

    attribute :handle, :string do
      description """
      The identifier of the hardware type.

      It should start with a lower case ASCII letter and only contain \
      lower case ASCII letters, digits and the hyphen - symbol.
      """

      allow_nil? false
    end

    attribute :name, :string do
      description "The display name of the hardware type."
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :part_numbers, Edgehog.Devices.HardwareTypePartNumber do
      description "The list of part numbers associated with the hardware type."
    end

    # TODO: :system_model
  end

  aggregates do
    list :part_number_strings, :part_numbers, :part_number
  end

  identities do
    # These have to be named this way to match the existing unique indexes
    # we already have. Ash uses identities to add a `unique_constraint` to the
    # Ecto changeset, so names have to match. There's no need to explicitly add
    # :tenant_id in the fields because identity in a multitenant resource are
    # automatically scoped to a specific :tenant_id
    # TODO: change index names when we generate migrations at the end of the porting
    identity :handle_tenant_id, [:handle]
    identity :name_tenant_id, [:name]
  end

  validations do
    validate Validations.slug(:handle)
  end

  postgres do
    table "hardware_types"
    repo Edgehog.Repo
  end
end
