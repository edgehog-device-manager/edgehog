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

defmodule Edgehog.BaseImages.BaseImage do
  use Edgehog.MultitenantResource,
    domain: Edgehog.BaseImages,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.BaseImages.BaseImage.Changes
  alias Edgehog.Localization
  alias Edgehog.Validations

  resource do
    description """
    Represents an uploaded Base Image.

    A base image represents a downloadable base image that can be installed on a device
    """
  end

  graphql do
    type :base_image

    queries do
      get :base_image, :get
    end

    mutations do
      create :create_base_image, :create do
        relay_id_translations input: [base_image_collection_id: :base_image_collection]
      end

      update :update_base_image, :update
      destroy :delete_base_image, :destroy
    end
  end

  actions do
    create :create do
      description "Create a new base image in a base image collection."
      primary? true

      accept [:starting_version_requirement, :version]

      argument :base_image_collection_id, :id do
        description "The ID of the base image collection this base image will belong to."
        allow_nil? false
      end

      argument :file, Edgehog.Types.Upload do
        description "The base image file, which will be uploaded to the storage."
        allow_nil? false
      end

      argument :localized_descriptions, {:array, Localization.LocalizedAttribute} do
        description "A list of descriptions in different languages."
      end

      argument :localized_release_display_names, {:array, Localization.LocalizedAttribute} do
        description "A list of release display names in different languages."
      end

      change Changes.HandleFileUpload
      change manage_relationship(:base_image_collection_id, :base_image_collection, type: :append)

      change {Localization.Changes.UpsertLocalizedAttribute,
              input_argument: :localized_descriptions, target_attribute: :description}

      change {Localization.Changes.UpsertLocalizedAttribute,
              input_argument: :localized_release_display_names,
              target_attribute: :release_display_name}
    end

    create :create_fixture do
      accept [:starting_version_requirement, :version, :url]

      argument :base_image_collection_id, :id do
        description "The ID of the base image collection this base image will belong to."
        allow_nil? false
      end

      argument :localized_descriptions, {:array, Localization.LocalizedAttribute} do
        description "A list of descriptions in different languages."
      end

      argument :localized_release_display_names, {:array, Localization.LocalizedAttribute} do
        description "A list of release display names in different languages."
      end

      change manage_relationship(:base_image_collection_id, :base_image_collection, type: :append)

      change {Localization.Changes.UpsertLocalizedAttribute,
              input_argument: :localized_descriptions, target_attribute: :description}

      change {Localization.Changes.UpsertLocalizedAttribute,
              input_argument: :localized_release_display_names,
              target_attribute: :release_display_name}
    end

    read :get do
      description "Returns a single base image."
      get? true
    end

    read :list do
      description "Returns a list of base images."
      primary? true
    end

    update :update do
      description "Updates a base image."
      primary? true

      # Needed because UpsertLocalizedAttribute is not atomic
      require_atomic? false

      argument :localized_descriptions, {:array, Localization.LocalizedAttributeUpdateInput} do
        description "A list of descriptions in different languages."
      end

      argument :localized_release_display_names,
               {:array, Localization.LocalizedAttributeUpdateInput} do
        description "A list of release display names in different languages."
      end

      accept [:starting_version_requirement]

      change {Localization.Changes.UpsertLocalizedAttribute,
              input_argument: :localized_descriptions, target_attribute: :description}

      change {Localization.Changes.UpsertLocalizedAttribute,
              input_argument: :localized_release_display_names,
              target_attribute: :release_display_name}
    end

    destroy :destroy do
      description "Deletes a base image."
      primary? true

      change Changes.HandleFileDeletion
    end

    destroy :destroy_fixture
  end

  validations do
    validate {Validations.Version, attribute: :version} do
      where changing(:version)
    end

    validate {Validations.VersionRequirement, attribute: :starting_version_requirement} do
      where changing(:starting_version_requirement)
    end
  end

  attributes do
    integer_primary_key :id

    attribute :version, :string do
      description "The base image version."
      public? true
      allow_nil? false
    end

    attribute :starting_version_requirement, :string do
      description "The starting version requirement for the base image."
      public? true
    end

    attribute :url, :string do
      description "The url where the base image can be downloaded."
      public? true
      allow_nil? false
    end

    attribute :description, :map
    attribute :release_display_name, :map

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :base_image_collection, Edgehog.BaseImages.BaseImageCollection do
      description "The base image collection that this base image belongs to."
      public? true
      attribute_public? false
      allow_nil? false
    end
  end

  calculations do
    calculate :localized_descriptions, {:array, Localization.LocalizedAttribute} do
      public? true
      description "A list of descriptions in different languages."
      calculation {Localization.Calculations.LocalizedAttributes, attribute: :description}
      argument :preferred_language_tags, {:array, :string}
    end

    calculate :localized_release_display_names, {:array, Localization.LocalizedAttribute} do
      public? true
      description "A list of release display names in different languages."

      calculation {Localization.Calculations.LocalizedAttributes,
                   attribute: :release_display_name}

      argument :preferred_language_tags, {:array, :string}
    end
  end

  identities do
    # These have to be named this way to match the existing unique indexes
    # we already have. Ash uses identities to add a `unique_constraint` to the
    # Ecto changeset, so names have to match. There's no need to explicitly add
    # :tenant_id in the fields because identity in a multitenant resource are
    # automatically scoped to a specific :tenant_id
    # TODO: change index names when we generate migrations at the end of the porting
    identity :version_base_image_collection_id_tenant_id, [
      :version,
      :base_image_collection_id,
      :tenant_id
    ]
  end

  postgres do
    table "base_images"
    repo Edgehog.Repo
  end
end
