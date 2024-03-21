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

defmodule Edgehog.Devices.SystemModel do
  use Edgehog.MultitenantResource,
    api: Edgehog.Devices,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.Devices.SystemModel.Changes
  alias Edgehog.Devices.SystemModel.Validations

  resource do
    description """
    A system model corresponds to what the users thinks as functionally
    equivalent devices (e.g. two revisions of a device containing two different
    embedded chips but having the same enclosure and the same functionality).
    Each SystemModel must be associated to a specific HardwareType.
    """
  end

  graphql do
    type :system_model

    hide_fields [:tenant, :part_number_strings]

    queries do
      get :system_model, :get
      list :system_models, :list
    end

    mutations do
      create :create_system_model, :create do
        relay_id_translations input: [hardware_type_id: :hardware_type]
      end

      update :update_system_model, :update
      destroy :delete_system_model, :destroy
    end
  end

  actions do
    read :get do
      description "Returns a system model."
      get? true
    end

    read :list do
      description "Returns a list of system models."
      primary? true
    end

    create :create do
      description "Creates a system model."
      primary? true

      argument :hardware_type_id, :id do
        description "The ID of the hardware type that can be used by devices of this model"
        allow_nil? false
      end

      argument :part_numbers, {:array, :string} do
        description "The list of part numbers associated with the system model."
        allow_nil? false
        constraints min_length: 1
      end

      argument :picture_file, Edgehog.Types.Upload do
        description "A picture representing the system model that will be uploaded to a bucket."
      end

      validate Validations.EitherPictureUrlOrPictureFile

      # TODO: see issue #228, which is still relevant
      change manage_relationship(:part_numbers,
               on_lookup: :relate,
               on_no_match: :create,
               value_is_key: :part_number,
               use_identities: [:part_number_tenant_id]
             )

      change manage_relationship(:hardware_type_id, :hardware_type, type: :append)
      change Changes.HandlePictureUpload
    end

    update :update do
      description "Updates an system model."
      primary? true

      argument :part_numbers, {:array, :string} do
        description "The list of part numbers associated with the system model."
        constraints min_length: 1
      end

      argument :picture_file, Edgehog.Types.Upload do
        description "A picture representing the system model that will be uploaded to a bucket."
      end

      validate Validations.EitherPictureUrlOrPictureFile

      change manage_relationship(:part_numbers,
               on_lookup: :relate,
               on_no_match: :create,
               on_missing: :destroy,
               value_is_key: :part_number,
               use_identities: [:part_number_tenant_id]
             )

      change Changes.HandlePictureUpload
      change Changes.HandlePictureDeletion
    end

    destroy :destroy do
      description "Deletes a system model."
      primary? true

      change {Changes.HandlePictureDeletion, force?: true}
    end
  end

  attributes do
    integer_primary_key :id

    attribute :handle, :string do
      description """
      The identifier of the system model.

      It should start with a lower case ASCII letter and only contain \
      lower case ASCII letters, digits and the hyphen - symbol.
      """

      allow_nil? false
    end

    attribute :name, :string do
      description "The display name of the system model."
      allow_nil? false
    end

    attribute :picture_url, :string do
      description "A URL to a picture representing the system model."
    end

    # TODO: localized description

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :part_numbers, Edgehog.Devices.SystemModelPartNumber do
      description "The list of part numbers associated with the system model."
    end

    belongs_to :hardware_type, Edgehog.Devices.HardwareType do
      description "The Hardware type associated with the System Model"
    end
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
    validate Edgehog.Validations.slug(:handle)
  end

  postgres do
    table "system_models"
    repo Edgehog.Repo
  end
end
