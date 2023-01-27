#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.BaseImagesTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Resolvers

  @desc """
  Represents a collection of Base Images.

  A base image collection represents the collection of all Base Images that \
  can run on a specific System Model.
  """
  node object(:base_image_collection) do
    @desc "The display name of the base image collection."
    field :name, non_null(:string)

    @desc "The identifier of the base image collection."
    field :handle, non_null(:string)

    @desc "The System Model associated with the Base Image Collection"
    field :system_model, :system_model

    @desc "The Base Images associated with the Base Image Collection"
    field :base_images, non_null(list_of(non_null(:base_image))) do
      &Resolvers.BaseImages.list_base_images_for_collection/3
    end
  end

  @desc """
  Represents an uploaded Base Image.

  A base image represents a downloadable base image that can be installed on a device
  """
  node object(:base_image) do
    @desc "The base image version"
    field :version, non_null(:string)

    @desc "The url where the base image can be downloaded"
    field :url, non_null(:string)

    @desc "The starting version requirement for the base image"
    field :starting_version_requirement, :string

    @desc """
    The localized description of the base image
    The language of the description can be controlled passing an \
    Accept-Language header in the request. If no such header is present, the \
    default tenant language is returned.
    """
    field :description, :string do
      resolve &Resolvers.BaseImages.extract_localized_description/3
    end

    @desc """
    The localized release display name of the base image
    The language of the description can be controlled passing an \
    Accept-Language header in the request. If no such header is present, the \
    default tenant language is returned.
    """
    field :release_display_name, :string do
      resolve &Resolvers.BaseImages.extract_localized_release_display_name/3
    end

    @desc "The Base Image Collection the Base Image belongs to"
    field :base_image_collection, non_null(:base_image_collection)
  end

  object :base_images_queries do
    @desc "Fetches the list of all base image collections."
    field :base_image_collections, non_null(list_of(non_null(:base_image_collection))) do
      resolve &Resolvers.BaseImages.list_base_image_collections/2
    end

    @desc "Fetches a single base image collection."
    field :base_image_collection, :base_image_collection do
      @desc "The ID of the base image collection."
      arg :id, non_null(:id)

      middleware Absinthe.Relay.Node.ParseIDs, id: :base_image_collection
      resolve &Resolvers.BaseImages.find_base_image_collection/2
    end

    @desc "Fetches a single base image."
    field :base_image, :base_image do
      @desc "The ID of the base image."
      arg :id, non_null(:id)

      middleware Absinthe.Relay.Node.ParseIDs, id: :base_image
      resolve &Resolvers.BaseImages.find_base_image/2
    end
  end

  object :base_images_mutations do
    @desc "Creates a new base image collection."
    payload field :create_base_image_collection do
      input do
        @desc "The display name of the base image collection."
        field :name, non_null(:string)

        @desc """
        The identifier of the base image collection.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, non_null(:string)

        @desc """
        The ID of the system model that is targeted by this base image collection
        """
        field :system_model_id, non_null(:id)
      end

      output do
        @desc "The created base image collection."
        field :base_image_collection, non_null(:base_image_collection)
      end

      middleware Absinthe.Relay.Node.ParseIDs, system_model_id: :system_model

      resolve &Resolvers.BaseImages.create_base_image_collection/2
    end

    @desc "Updates a base image collection."
    payload field :update_base_image_collection do
      input do
        @desc "The ID of the base image collection to be updated."
        field :base_image_collection_id, non_null(:id)

        @desc "The display name of the base image collection."
        field :name, :string

        @desc """
        The identifier of the base image collection.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, :string
      end

      output do
        @desc "The updated base image collection."
        field :base_image_collection, non_null(:base_image_collection)
      end

      middleware Absinthe.Relay.Node.ParseIDs, base_image_collection_id: :base_image_collection

      resolve &Resolvers.BaseImages.update_base_image_collection/2
    end

    @desc "Deletes a base image collection."
    payload field :delete_base_image_collection do
      input do
        @desc "The ID of the base image collection to be deleted."
        field :base_image_collection_id, non_null(:id)
      end

      output do
        @desc "The deleted base image collection."
        field :base_image_collection, non_null(:base_image_collection)
      end

      middleware Absinthe.Relay.Node.ParseIDs, base_image_collection_id: :base_image_collection
      resolve &Resolvers.BaseImages.delete_base_image_collection/2
    end

    @desc "Create a new base image in a base image collection."
    payload field :create_base_image do
      input do
        @desc "The ID of the Base Image Collection this Base Image will belong to"
        field :base_image_collection_id, non_null(:id)

        @desc "The base image version"
        field :version, non_null(:string)

        @desc "The base image file, which will be uploaded to the storage"
        field :file, non_null(:upload)

        @desc "An optional starting version requirement for the base image"
        field :starting_version_requirement, :string

        @desc """
        An optional localized description. This description can currently only use the \
        default tenant locale.
        """
        field :description, :localized_text_input

        @desc """
        An optional relase display name. This can currently only use the \
        default tenant locale.
        """
        field :release_display_name, :localized_text_input
      end

      output do
        @desc "The created base image."
        field :base_image, non_null(:base_image)
      end

      middleware Absinthe.Relay.Node.ParseIDs, base_image_collection_id: :base_image_collection

      resolve &Resolvers.BaseImages.create_base_image/2
    end

    @desc "Updates a base image."
    payload field :update_base_image do
      input do
        @desc "The ID of the base image to be updated."
        field :base_image_id, non_null(:id)

        @desc "The starting version requirement for the base image"
        field :starting_version_requirement, :string

        @desc """
        The localized description. This description can currently only use the \
        default tenant locale.
        """
        field :description, :localized_text_input

        @desc """
        The localized relase display name. This can currently only use the \
        default tenant locale.
        """
        field :release_display_name, :localized_text_input
      end

      output do
        @desc "The updated base image."
        field :base_image, non_null(:base_image)
      end

      middleware Absinthe.Relay.Node.ParseIDs, base_image_id: :base_image

      resolve &Resolvers.BaseImages.update_base_image/2
    end
  end
end
