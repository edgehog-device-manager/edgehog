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
  end
end
